import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../home/domain/mock_data.dart';
import '../../application/duel_providers.dart';
import '../../domain/duel_invite.dart';
import '../../domain/duel_match.dart';
import '../../domain/duel_player.dart';
import '../../domain/duel_questions.dart';
import '../widgets/invite_qr_code.dart';

// ═══════════════════════════════════════════════════════════════════════════
// DuelRaceScreen — async head-to-head. Two roles share this screen:
//
//   • Challenger (.challenge): plays a fresh run to "set the pace". On finish
//     the run is published as a challenge (a code + QR a friend can scan to try
//     to beat it).
//   • Opponent (.accept): plays a duel loaded by code, racing the challenger's
//     recorded run as a "ghost". On finish the result is submitted and the
//     winner is computed.
//
// You always answer for real; the opponent track replays the challenger's
// stored per-question correctness, so the fastest-correct energy is preserved.
// ═══════════════════════════════════════════════════════════════════════════
class DuelRaceScreen extends ConsumerStatefulWidget {
  /// Play a fresh run and publish it as a challenge. [target], when set, sends
  /// the challenge to a specific player's inbox instead of an open pool.
  const DuelRaceScreen.challenge({super.key, this.target}) : duel = null;

  /// Play an existing challenge as the opponent.
  const DuelRaceScreen.accept({super.key, required DuelMatch this.duel})
      : target = null;

  final DuelPlayer? target;
  final DuelMatch? duel;

  bool get isChallenger => duel == null;

  @override
  ConsumerState<DuelRaceScreen> createState() => _DuelRaceScreenState();
}

class _DuelRaceScreenState extends ConsumerState<DuelRaceScreen> {
  late final String _topic;
  late final List<String> _questionIds;
  late final List<MockQuestion> _questions;

  // Scripted opponent reveal cadence (only used in .accept mode).
  static const _oppSecondsPerQuestion = 7;

  int _qIndex = 0;
  int? _picked;
  int _myScore = 0;
  final List<bool> _myAnswers = [];

  // Opponent ghost (accept mode only).
  int _oppScore = 0;
  int _oppAnswered = 0;
  Timer? _oppTicker;

  Timer? _advanceTimer;
  final Stopwatch _raceWatch = Stopwatch()..start();

  bool _finishing = false;
  bool _finished = false;
  String? _error;

  /// The created (challenger) or completed (opponent) duel, once finished.
  DuelMatch? _resultDuel;

  @override
  void initState() {
    super.initState();
    if (widget.isChallenger) {
      final pick = DuelQuestions.pick();
      _topic = pick.topic;
      _questionIds = pick.questionIds;
    } else {
      _topic = widget.duel!.topic;
      _questionIds = widget.duel!.questionIds;
    }
    _questions = DuelQuestions.resolve(_questionIds);

    if (!widget.isChallenger) {
      // Replay the challenger's run as a ghost, one answer every few seconds.
      _oppTicker = Timer.periodic(
        const Duration(seconds: _oppSecondsPerQuestion),
        (_) {
          if (_oppAnswered >= _questions.length) return;
          setState(() {
            if (_ghostCorrectAt(_oppAnswered)) _oppScore++;
            _oppAnswered++;
          });
        },
      );
    }
  }

  @override
  void dispose() {
    _oppTicker?.cancel();
    _advanceTimer?.cancel();
    super.dispose();
  }

  /// Was the challenger correct on question [i]? Uses the stored per-question
  /// answers, falling back to a score-derived guess for legacy rows.
  bool _ghostCorrectAt(int i) {
    final answers = widget.duel?.challengerAnswers ?? const [];
    if (i < answers.length) return answers[i];
    return i < (widget.duel?.challengerScore ?? 0);
  }

  void _pick(int i) {
    if (_picked != null || _finished || _finishing) return;
    final correct = i == _questions[_qIndex].correctIndex;
    HapticFeedback.mediumImpact();
    setState(() {
      _picked = i;
      _myAnswers.add(correct);
      if (correct) _myScore++;
    });
    _advanceTimer = Timer(const Duration(milliseconds: 900), _next);
  }

  void _next() {
    if (_qIndex >= _questions.length - 1) {
      _finish();
      return;
    }
    setState(() {
      _qIndex++;
      _picked = null;
    });
  }

  Future<void> _finish() async {
    _oppTicker?.cancel();
    _raceWatch.stop();
    // Settle the ghost's remaining answers for a complete final score.
    while (_oppAnswered < _questions.length) {
      if (_ghostCorrectAt(_oppAnswered)) _oppScore++;
      _oppAnswered++;
    }
    setState(() => _finishing = true);

    final controller = ref.read(duelControllerProvider);
    try {
      final DuelMatch duel;
      if (widget.isChallenger) {
        duel = await controller.createChallenge(
          topic: _topic,
          questionIds: _questionIds,
          answers: _myAnswers,
          score: _myScore,
          target: widget.target,
        );
      } else {
        duel = await controller.submitResult(
          duel: widget.duel!,
          score: _myScore,
        );
      }
      if (!mounted) return;
      setState(() {
        _resultDuel = duel;
        _finished = true;
        _finishing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not save your duel. Check your connection.';
        _finishing = false;
        _finished = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    if (_finishing) {
      return Scaffold(
        backgroundColor: p.bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_finished) {
      if (_error != null) {
        return _ErrorView(message: _error!, onDone: () => Navigator.pop(context));
      }
      if (widget.isChallenger) {
        return _ChallengeReadyView(
          duel: _resultDuel!,
          myScore: _myScore,
          total: _questions.length,
          onDone: () => Navigator.pop(context),
        );
      }
      final me = ref.read(currentPlayerProvider);
      return _RaceResultView(
        opponentName: widget.duel!.challengerName,
        myScore: _myScore,
        oppScore: widget.duel!.challengerScore ?? _oppScore,
        total: _questions.length,
        seconds: _raceWatch.elapsed.inSeconds,
        outcome: _resultDuel?.outcomeFor(me.id),
        onDone: () => Navigator.pop(context),
      );
    }

    final q = _questions[_qIndex];
    final oppName = widget.isChallenger
        ? 'You set the pace'
        : widget.duel!.challengerName.split(' ').first;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: [
            _RaceHeader(
              opponentName: oppName,
              soloPace: widget.isChallenger,
              myScore: _myScore,
              oppScore: _oppScore,
              myProgress: _qIndex / _questions.length,
              oppProgress: _oppAnswered / _questions.length,
              onClose: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0.1, 0), end: Offset.zero)
                        .animate(anim),
                    child: child,
                  ),
                ),
                child: SingleChildScrollView(
                  key: ValueKey(_qIndex),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                TagChip(label: q.subject, color: p.accent),
                                const Spacer(),
                                Text(
                                  'Q${_qIndex + 1}/${_questions.length}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(color: p.textTertiary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              q.question,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(height: 1.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (var i = 0; i < q.options.length; i++) ...[
                        _RaceOption(
                          label: q.options[i],
                          index: i,
                          picked: _picked,
                          correctIndex: q.correctIndex,
                          onTap: () => _pick(i),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header: live score + both racers' progress ───────────────────────────────
class _RaceHeader extends StatelessWidget {
  const _RaceHeader({
    required this.opponentName,
    required this.soloPace,
    required this.myScore,
    required this.oppScore,
    required this.myProgress,
    required this.oppProgress,
    required this.onClose,
  });

  final String opponentName;
  final bool soloPace;
  final int myScore, oppScore;
  final double myProgress, oppProgress;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 20, 12),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(bottom: BorderSide(color: p.hairline, width: 1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onClose,
                icon: Icon(Icons.close_rounded, color: p.textSecondary),
                tooltip: 'Forfeit',
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('You', style: text.labelLarge),
                    const SizedBox(width: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Text(
                        soloPace ? '$myScore' : '$myScore – $oppScore',
                        key: ValueKey('$myScore-$oppScore'),
                        style: text.headlineSmall?.copyWith(
                          color: p.accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      soloPace ? '' : opponentName,
                      style: text.labelLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 40), // balance the close button
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                _RacerTrack(
                  label: 'You',
                  progress: myProgress,
                  color: p.accent,
                ),
                const SizedBox(height: 6),
                _RacerTrack(
                  label: soloPace ? '…' : opponentName,
                  progress: oppProgress,
                  color: const Color(0xFFEC4899),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RacerTrack extends StatelessWidget {
  const _RacerTrack({
    required this.label,
    required this.progress,
    required this.color,
  });

  final String label;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(label,
              style: text.labelSmall?.copyWith(color: p.textTertiary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: p.surfaceHigh,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.flag_rounded, size: 14, color: p.textTertiary),
      ],
    );
  }
}

// ─── Option (instant reveal) ──────────────────────────────────────────────────
class _RaceOption extends StatelessWidget {
  const _RaceOption({
    required this.label,
    required this.index,
    required this.picked,
    required this.correctIndex,
    required this.onTap,
  });

  final String label;
  final int index;
  final int? picked;
  final int correctIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    const green = Color(0xFF059669);
    const red = Color(0xFFE11D48);
    final answered = picked != null;

    Color bg = p.surface;
    Color border = p.hairline;
    Color fg = p.textPrimary;
    double width = 1;

    if (answered && index == correctIndex) {
      bg = green.withValues(alpha: 0.10);
      border = green;
      fg = green;
      width = 2;
    } else if (answered && index == picked) {
      bg = red.withValues(alpha: 0.08);
      border = red;
      fg = red;
      width = 2;
    } else if (answered) {
      fg = p.textTertiary;
    }

    return Pressable(
      onTap: answered ? null : onTap,
      enabled: !answered,
      scale: 0.98,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: width),
        ),
        child: Row(
          children: [
            Text(
              String.fromCharCode(65 + index),
              style: text.labelLarge?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: text.bodyMedium?.copyWith(color: fg)),
            ),
            if (answered && index == correctIndex)
              const Icon(Icons.check_circle_rounded, color: green, size: 20)
            else if (answered && index == picked)
              const Icon(Icons.cancel_rounded, color: red, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Result (opponent) ────────────────────────────────────────────────────────
class _RaceResultView extends StatelessWidget {
  const _RaceResultView({
    required this.opponentName,
    required this.myScore,
    required this.oppScore,
    required this.total,
    required this.seconds,
    required this.outcome,
    required this.onDone,
  });

  final String opponentName;
  final int myScore, oppScore, total, seconds;

  /// 'win' | 'loss' | 'draw' — the persisted outcome, falling back to scores.
  final String? outcome;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final won = outcome == 'win' || (outcome == null && myScore > oppScore);
    final draw = outcome == 'draw' || (outcome == null && myScore == oppScore);
    final color = won
        ? const Color(0xFF059669)
        : draw
            ? p.accent
            : const Color(0xFFE11D48);

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              StaggeredEntrance(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    won
                        ? Icons.emoji_events_rounded
                        : draw
                            ? Icons.handshake_rounded
                            : Icons.replay_rounded,
                    color: color,
                    size: 46,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              StaggeredEntrance(
                index: 1,
                child: Text(
                  won
                      ? 'You won!'
                      : draw
                          ? 'Dead heat!'
                          : 'So close!',
                  style: text.displayMedium,
                ),
              ),
              const SizedBox(height: 10),
              StaggeredEntrance(
                index: 2,
                child: Text(
                  '$myScore – $oppScore against ${opponentName.split(' ').first}'
                  '  ·  finished in ${seconds}s',
                  style: text.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 28),
              StaggeredEntrance(
                index: 3,
                child: Row(
                  children: [
                    Expanded(
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            Text('You',
                                style: text.labelSmall
                                    ?.copyWith(color: p.textTertiary)),
                            const SizedBox(height: 4),
                            Text('$myScore/$total',
                                style: text.headlineSmall?.copyWith(
                                    color: p.accent,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            Text(opponentName.split(' ').first,
                                style: text.labelSmall
                                    ?.copyWith(color: p.textTertiary)),
                            const SizedBox(height: 4),
                            Text('$oppScore/$total',
                                style: text.headlineSmall?.copyWith(
                                    color: const Color(0xFFEC4899),
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              AppButton(label: 'Back to the arena', onTap: onDone),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Result (challenger): your run is now a shareable challenge ────────────────
class _ChallengeReadyView extends StatelessWidget {
  const _ChallengeReadyView({
    required this.duel,
    required this.myScore,
    required this.total,
    required this.onDone,
  });

  final DuelMatch duel;
  final int myScore, total;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final code = DuelInvite.pretty(duel.code);
    final payload = DuelInvite.payloadFor(duel.code);
    final targeted = duel.opponentName != null;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              StaggeredEntrance(
                child: Text('Challenge ready', style: text.displaySmall),
              ),
              const SizedBox(height: 8),
              StaggeredEntrance(
                index: 1,
                child: Text(
                  targeted
                      ? 'Sent to ${duel.opponentName!.split(' ').first}. '
                          'You scored $myScore/$total — they\'ll race the same '
                          '${duel.topic} questions to beat it.'
                      : 'You scored $myScore/$total on ${duel.topic}. Share this '
                          'code — a friend races the same questions to beat it.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium,
                ),
              ),
              const SizedBox(height: 24),
              StaggeredEntrance(
                index: 2,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: p.accent.withValues(alpha: 0.28),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      InviteQrCode(data: payload, size: 220, foreground: p.accent),
                      const SizedBox(height: 14),
                      Text(
                        code,
                        style: text.titleLarge?.copyWith(
                          color: const Color(0xFF12101A),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              StaggeredEntrance(
                index: 3,
                child: Pressable(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Code $code copied'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: p.surfaceHigh,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.hairline),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded, size: 18, color: p.textSecondary),
                        const SizedBox(width: 10),
                        Text('Copy code', style: text.labelLarge),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              AppButton(label: 'Done', onTap: onDone),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Error fallback ───────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onDone});
  final String message;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, color: p.textTertiary, size: 48),
              const SizedBox(height: 16),
              Text('Hmm.', style: text.headlineSmall),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: text.bodyMedium),
              const SizedBox(height: 28),
              AppButton(label: 'Back to the arena', onTap: onDone),
            ],
          ),
        ),
      ),
    );
  }
}
