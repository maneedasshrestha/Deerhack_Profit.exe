import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../home/domain/mock_data.dart';
import '../../../home/domain/plan_data.dart';

// ═══════════════════════════════════════════════════════════════════════════
// DuelRaceScreen — mock head-to-head. Both players get the same questions;
// you answer for real, the opponent answers on a simulated schedule. Instant
// right/wrong feedback, auto-advance, fastest-correct energy throughout.
// (POC: the opponent is scripted — swap for the realtime backend later.)
// ═══════════════════════════════════════════════════════════════════════════
class DuelRaceScreen extends StatefulWidget {
  const DuelRaceScreen({
    super.key,
    this.opponentName = 'Priya Shah',
  });

  final String opponentName;

  @override
  State<DuelRaceScreen> createState() => _DuelRaceScreenState();
}

class _DuelRaceScreenState extends State<DuelRaceScreen> {
  late final List<MockQuestion> _questions =
      PlanData.mockTestQuestions.take(5).toList();

  // Scripted opponent: answers one question every few seconds with this
  // right/wrong pattern. Tuned so a decent run is a close match.
  static const _oppPattern = [true, false, true, true, false];
  static const _oppSecondsPerQuestion = 7;

  int _qIndex = 0;
  int? _picked;
  int _myScore = 0;
  int _oppScore = 0;
  int _oppAnswered = 0;
  bool _finished = false;

  Timer? _oppTicker;
  Timer? _advanceTimer;
  final Stopwatch _raceWatch = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    _oppTicker = Timer.periodic(
      const Duration(seconds: _oppSecondsPerQuestion),
      (_) {
        if (_oppAnswered >= _questions.length) return;
        setState(() {
          if (_oppPattern[_oppAnswered % _oppPattern.length]) _oppScore++;
          _oppAnswered++;
        });
      },
    );
  }

  @override
  void dispose() {
    _oppTicker?.cancel();
    _advanceTimer?.cancel();
    super.dispose();
  }

  void _pick(int i) {
    if (_picked != null || _finished) return;
    final correct = i == _questions[_qIndex].correctIndex;
    HapticFeedback.mediumImpact();
    setState(() {
      _picked = i;
      if (correct) _myScore++;
    });
    _advanceTimer = Timer(const Duration(milliseconds: 900), _next);
  }

  void _next() {
    if (_qIndex >= _questions.length - 1) {
      // Race over for you — resolve the opponent's remaining answers so the
      // final score is complete.
      _oppTicker?.cancel();
      _raceWatch.stop();
      setState(() {
        while (_oppAnswered < _questions.length) {
          if (_oppPattern[_oppAnswered % _oppPattern.length]) _oppScore++;
          _oppAnswered++;
        }
        _finished = true;
      });
      return;
    }
    setState(() {
      _qIndex++;
      _picked = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    if (_finished) {
      return _RaceResultView(
        opponentName: widget.opponentName,
        myScore: _myScore,
        oppScore: _oppScore,
        total: _questions.length,
        seconds: _raceWatch.elapsed.inSeconds,
        onDone: () => Navigator.of(context).pop(),
      );
    }

    final q = _questions[_qIndex];

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: [
            _RaceHeader(
              opponentName: widget.opponentName,
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
    required this.myScore,
    required this.oppScore,
    required this.myProgress,
    required this.oppProgress,
    required this.onClose,
  });

  final String opponentName;
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
                        '$myScore – $oppScore',
                        key: ValueKey('$myScore-$oppScore'),
                        style: text.headlineSmall?.copyWith(
                          color: p.accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      opponentName.split(' ').first,
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
                  label: opponentName.split(' ').first,
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

// ─── Result ───────────────────────────────────────────────────────────────────
class _RaceResultView extends StatelessWidget {
  const _RaceResultView({
    required this.opponentName,
    required this.myScore,
    required this.oppScore,
    required this.total,
    required this.seconds,
    required this.onDone,
  });

  final String opponentName;
  final int myScore, oppScore, total, seconds;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final won = myScore > oppScore;
    final draw = myScore == oppScore;
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
