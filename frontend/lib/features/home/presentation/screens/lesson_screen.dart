import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../application/study_providers.dart';
import '../../domain/mock_data.dart';
import '../widgets/streak_celebration_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// LessonScreen — daily MCQ level.
//
// Guided feedback: a hint lives right under the question, revealed on demand
// (or automatically after a first miss) — it nudges, never answers. Only a
// second miss reveals the answer, with the reason each distractor fails.
// Questions can be starred for later revision from the profile.
// ═══════════════════════════════════════════════════════════════════════════
class LessonScreen extends ConsumerStatefulWidget {
  const LessonScreen({
    super.key,
    required this.title,
    required this.questions,
    this.onCompleted,
  });

  final String title;
  final List<MockQuestion> questions;

  /// Called once the level is finished, with the stars (0–3) earned — lets the
  /// week map mark this level done and unlock the next.
  final ValueChanged<int>? onCompleted;

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

enum _Phase { answering, hinted, correct, revealed }

class _LessonScreenState extends ConsumerState<LessonScreen> {
  int _qIndex = 0;
  int? _selected;
  _Phase _phase = _Phase.answering;
  bool _usedHint = false;
  bool _hintVisible = false;
  final Set<int> _eliminated = {}; // wrong picks this question
  final List<bool> _results = []; // correct on ≤2 attempts?
  int _xp = 0;

  MockQuestion get _q => widget.questions[_qIndex];
  bool get _done => _results.length == widget.questions.length &&
      (_phase == _Phase.correct || _phase == _Phase.revealed);
  int get _correctCount => _results.where((r) => r).length;

  int get _stars {
    if (_results.isEmpty) return 0;
    final acc = _correctCount / _results.length;
    if (acc >= 0.99) return 3;
    if (acc >= 0.75) return 2;
    if (_correctCount > 0) return 1;
    return 0;
  }

  void _showHint() {
    if (_hintVisible || _q.hint == null) return;
    HapticFeedback.lightImpact();
    setState(() {
      _usedHint = true;
      _hintVisible = true;
    });
  }

  void _check() {
    final sel = _selected;
    if (sel == null) return;
    if (sel == _q.correctIndex) {
      HapticFeedback.mediumImpact();
      setState(() {
        _results.add(true);
        _xp += _usedHint ? 10 : 20;
        _phase = _Phase.correct;
      });
    } else if (!_usedHint && _q.hint != null) {
      // First miss: surface the hint inline and let them retry.
      HapticFeedback.lightImpact();
      setState(() {
        _usedHint = true;
        _hintVisible = true;
        _eliminated.add(sel);
        _selected = null;
        _phase = _Phase.hinted;
      });
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _results.add(false);
        _eliminated.add(sel);
        _phase = _Phase.revealed;
      });
    }
  }

  void _retry() => setState(() => _phase = _Phase.answering);

  /// Finishing the day's MCQs extends the streak and shows the celebration,
  /// then returns to the week once the learner taps continue.
  void _finishWithStreak() {
    // Mark the level cleared so the week map unlocks the next node.
    widget.onCompleted?.call(_stars);
    final from = ref.read(streakProvider.notifier).registerDayComplete();
    final to = ref.read(streakProvider);
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute(
        builder: (_) => StreakCelebrationScreen(
          fromStreak: from,
          toStreak: to,
          onContinue: () {
            navigator.pop(); // close the celebration
            navigator.pop(); // leave the lesson, back to the week
          },
        ),
      ),
    );
  }

  void _next() {
    if (_qIndex >= widget.questions.length - 1) {
      setState(() {}); // _done now true → completion view
      return;
    }
    setState(() {
      _qIndex++;
      _selected = null;
      _usedHint = false;
      _hintVisible = false;
      _eliminated.clear();
      _phase = _Phase.answering;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    if (_done) {
      return _CompletionView(
        title: widget.title,
        stars: _stars,
        xp: _xp,
        correct: _correctCount,
        total: _results.length,
        onFinish: _finishWithStreak,
      );
    }

    final showPanel = _phase != _Phase.answering;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: [
            _LessonTopBar(
              progress: _results.length / widget.questions.length,
              xp: _xp,
              onClose: () => Navigator.of(context).pop(),
            ),
            _ResultDots(
              total: widget.questions.length,
              results: _results,
              currentIndex: _qIndex,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.12, 0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: SingleChildScrollView(
                  key: ValueKey(_qIndex),
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _QuestionCard(
                        question: _q,
                        index: _qIndex,
                        total: widget.questions.length,
                        hintVisible: _hintVisible,
                        onShowHint: _showHint,
                      ),
                      const SizedBox(height: 18),
                      for (var i = 0; i < _q.options.length; i++)
                        if (_q.options[i].isNotEmpty) ...[
                          _OptionTile(
                            label: _q.options[i],
                            index: i,
                            selected: _selected == i,
                            eliminated: _eliminated.contains(i),
                            revealedCorrect: (_phase == _Phase.correct ||
                                    _phase == _Phase.revealed) &&
                                i == _q.correctIndex,
                            revealedWrong: _phase == _Phase.revealed &&
                                _eliminated.contains(i),
                            enabled: _phase == _Phase.answering,
                            // The reason that belongs to this option, shown
                            // inline once the answer is revealed.
                            note: i == _q.correctIndex
                                ? _q.explanation
                                : (i < _q.whyWrong.length
                                    ? _q.whyWrong[i]
                                    : null),
                            onTap: () => setState(() => _selected = i),
                          ),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              clipBehavior: Clip.none,
              child: showPanel
                  ? _FeedbackPanel(
                      phase: _phase,
                      question: _q,
                      onRetry: _retry,
                      onNext: _next,
                      isLast: _qIndex >= widget.questions.length - 1,
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      child: AppButton(
                        label: 'Check',
                        onTap: _selected == null ? null : _check,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Top bar ──────────────────────────────────────────────────────────────────
class _LessonTopBar extends StatelessWidget {
  const _LessonTopBar({
    required this.progress,
    required this.xp,
    required this.onClose,
  });

  final double progress;
  final int xp;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 16, 2),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, color: p.textSecondary),
            tooltip: 'Exit',
          ),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: v,
                  minHeight: 12,
                  backgroundColor: p.surfaceHigh,
                  valueColor: AlwaysStoppedAnimation(p.accent),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Live XP counter — ticks up as answers land.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: TagChip(
              key: ValueKey(xp),
              label: '$xp XP',
              icon: Icons.bolt_rounded,
              color: const Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Per-question result dots ─────────────────────────────────────────────────
class _ResultDots extends StatelessWidget {
  const _ResultDots({
    required this.total,
    required this.results,
    required this.currentIndex,
  });

  final int total;
  final List<bool> results;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i < results.length
                      ? (results[i]
                          ? const Color(0xFF059669)
                          : const Color(0xFFE11D48).withValues(alpha: 0.6))
                      : i == currentIndex
                          ? p.accent.withValues(alpha: 0.5)
                          : p.surfaceHigh,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Question card (number, star, inline hint) ────────────────────────────────
class _QuestionCard extends ConsumerWidget {
  const _QuestionCard({
    required this.question,
    required this.index,
    required this.total,
    required this.hintVisible,
    required this.onShowHint,
  });

  final MockQuestion question;
  final int index;
  final int total;
  final bool hintVisible;
  final VoidCallback onShowHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final starred = ref.watch(starredQuestionsProvider).contains(question.id);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'QUESTION ${index + 1} OF $total',
                style: text.labelSmall?.copyWith(
                  color: p.textTertiary,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TagChip(label: question.subject, color: p.accent),
              const SizedBox(width: 6),
              Pressable(
                onTap: () => ref
                    .read(starredQuestionsProvider.notifier)
                    .toggle(question.id),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    starred ? Icons.star_rounded : Icons.star_border_rounded,
                    key: ValueKey(starred),
                    color: starred
                        ? const Color(0xFFF59E0B)
                        : p.textTertiary,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(question.question,
              style: text.bodyLarge?.copyWith(height: 1.5)),
          if (question.hint != null) ...[
            const SizedBox(height: 14),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: hintVisible
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: p.accentSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_rounded,
                              size: 17, color: p.accent),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              question.hint!,
                              style: text.labelMedium?.copyWith(
                                  color: p.textSecondary, height: 1.45),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: Pressable(
                        onTap: onShowHint,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                                color: p.accent.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lightbulb_outline_rounded,
                                  size: 15, color: p.accent),
                              const SizedBox(width: 6),
                              Text(
                                'Need a nudge?  −10 XP',
                                style: text.labelSmall?.copyWith(
                                  color: p.accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Option tile ──────────────────────────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.index,
    required this.selected,
    required this.eliminated,
    required this.revealedCorrect,
    required this.revealedWrong,
    required this.enabled,
    required this.onTap,
    this.note,
  });

  final String label;
  final int index;
  final bool selected, eliminated, revealedCorrect, revealedWrong, enabled;
  final VoidCallback onTap;

  /// The reason this option is right/wrong, revealed inline beneath it once the
  /// answer is shown. Null or empty → nothing extra.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    const green = Color(0xFF059669);
    const red = Color(0xFFE11D48);

    Color bg = p.surface;
    Color borderColor = p.hairline;
    Color fg = p.textPrimary;
    double borderWidth = 1;
    Widget? trailing;

    if (revealedCorrect) {
      bg = green.withValues(alpha: 0.10);
      borderColor = green;
      fg = green;
      borderWidth = 2;
      trailing = const Icon(Icons.check_circle_rounded, color: green, size: 20);
    } else if (revealedWrong || (eliminated && enabled)) {
      bg = red.withValues(alpha: 0.06);
      borderColor = red.withValues(alpha: 0.45);
      fg = p.textTertiary;
      trailing = Icon(Icons.cancel_rounded,
          color: red.withValues(alpha: 0.6), size: 20);
    } else if (selected) {
      bg = p.accentSoft;
      borderColor = p.accent;
      fg = p.accent;
      borderWidth = 2;
    }

    final canTap = enabled && !eliminated;

    return Pressable(
      onTap: canTap ? onTap : null,
      enabled: canTap,
      scale: 0.98,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (revealedCorrect
                        ? green
                        : selected
                            ? p.accent
                            : p.textTertiary)
                    .withValues(alpha: 0.14),
              ),
              child: Center(
                child: Text(
                  String.fromCharCode(65 + index),
                  style: text.labelMedium?.copyWith(
                    color: revealedCorrect
                        ? green
                        : selected
                            ? p.accent
                            : p.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: text.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight:
                      selected || revealedCorrect ? FontWeight.w600 : null,
                  decoration:
                      eliminated && enabled ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing],
              ],
            ),
            if ((revealedCorrect || revealedWrong) &&
                note != null &&
                note!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: Text(
                  note!,
                  style: text.bodySmall?.copyWith(
                      color: p.textSecondary, height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Feedback panel ───────────────────────────────────────────────────────────
class _FeedbackPanel extends StatefulWidget {
  const _FeedbackPanel({
    required this.phase,
    required this.question,
    required this.onRetry,
    required this.onNext,
    required this.isLast,
  });

  final _Phase phase;
  final MockQuestion question;
  final VoidCallback onRetry;
  final VoidCallback onNext;
  final bool isLast;

  @override
  State<_FeedbackPanel> createState() => _FeedbackPanelState();
}

class _FeedbackPanelState extends State<_FeedbackPanel> {
  // The tip is tucked away by default — only shown when explicitly toggled, so
  // the reveal stays uncluttered.
  bool _showTip = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final phase = widget.phase;
    final question = widget.question;

    // The hint itself lives under the question — this sheet only nudges the
    // learner back up to it.
    if (phase == _Phase.hinted) {
      return _Sheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(
              context,
              color: p.accent,
              icon: Icons.lightbulb_rounded,
              title: 'Not quite',
              subtitle: 'Take the hint under the question, then try again.',
            ),
            const SizedBox(height: 16),
            AppButton(label: 'Try again', height: 50, onTap: widget.onRetry),
          ],
        ),
      );
    }

    final correct = phase == _Phase.correct;
    const green = Color(0xFF059669);
    const red = Color(0xFFE11D48);
    // Clear right/wrong signal: green when correct, red when not.
    final color = correct ? green : red;
    final tip = question.tip;

    return _Sheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(
            context,
            color: color,
            icon: correct ? Icons.check_rounded : Icons.close_rounded,
            title: correct ? 'Correct' : 'Incorrect',
            subtitle: correct
                ? 'Nice work.'
                : 'See the reasoning under each option.',
          ),
          // The optional memory aid, revealed only on demand.
          if (tip != null && tip.isNotEmpty) ...[
            const SizedBox(height: 12),
            Pressable(
              onTap: () => setState(() => _showTip = !_showTip),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showTip
                        ? Icons.lightbulb_rounded
                        : Icons.lightbulb_outline_rounded,
                    size: 16,
                    color: p.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _showTip ? 'Hide tip' : 'Show tip',
                    style: text.labelMedium?.copyWith(
                      color: p.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(
                    _showTip
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: p.accent,
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _showTip
                  ? Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: p.accentSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        tip,
                        style: text.bodyMedium
                            ?.copyWith(color: p.textPrimary, height: 1.5),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
          const SizedBox(height: 16),
          AppButton(
            label: widget.isLast ? 'See results' : 'Continue',
            color: color,
            height: 52,
            onTap: widget.onNext,
          ),
        ],
      ),
    );
  }

  // Shared icon-badge + title + subtitle header.
  Widget _header(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: text.titleMedium
                    ?.copyWith(color: p.textPrimary, fontWeight: FontWeight.w700),
              ),
              Text(
                subtitle,
                style: text.labelMedium?.copyWith(color: p.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A bottom sheet shell with a rounded top, a grabber, and a lift shadow —
/// reused for both the hint nudge and the answer feedback.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: p.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─── Completion view ──────────────────────────────────────────────────────────
class _CompletionView extends StatelessWidget {
  const _CompletionView({
    required this.title,
    required this.stars,
    required this.xp,
    required this.correct,
    required this.total,
    required this.onFinish,
  });

  final String title;
  final int stars, xp, correct, total;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final accuracy = total == 0 ? 0 : (correct * 100) ~/ total;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              StaggeredEntrance(
                child: ProgressRing(
                  progress: accuracy / 100,
                  size: 132,
                  strokeWidth: 10,
                  color: p.accent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$accuracy%',
                          style: text.displayMedium
                              ?.copyWith(color: p.accent, fontSize: 34)),
                      Text('accuracy', style: text.labelSmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              StaggeredEntrance(
                index: 1,
                child: Text('Level complete!', style: text.displayMedium),
              ),
              const SizedBox(height: 6),
              StaggeredEntrance(
                index: 2,
                child: Text(title,
                    style: text.bodyLarge?.copyWith(color: p.textSecondary)),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 450 + i * 180),
                      curve: Curves.elasticOut,
                      builder: (context, v, _) => Transform.scale(
                        scale: v,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            i < stars
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: i < stars
                                ? const Color(0xFFF59E0B)
                                : p.textTertiary,
                            size: 46,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              StaggeredEntrance(
                index: 3,
                child: Row(
                  children: [
                    Expanded(
                        child: _StatBox(
                            value: '+$xp', label: 'XP', color: p.accent)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _StatBox(
                            value: '$correct/$total',
                            label: 'Correct',
                            color: const Color(0xFF059669))),
                  ],
                ),
              ),
              const Spacer(),
              AppButton(
                  label: 'Continue',
                  icon: Icons.local_fire_department_rounded,
                  onTap: onFinish),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox(
      {required this.value, required this.label, required this.color});
  final String value, label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(value,
              style: text.headlineSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: text.labelSmall),
        ],
      ),
    );
  }
}
