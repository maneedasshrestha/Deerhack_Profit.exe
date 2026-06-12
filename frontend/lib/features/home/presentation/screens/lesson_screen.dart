import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/mock_data.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// LessonScreen — gamified MCQ practice
// ═══════════════════════════════════════════════════════════════════════════════
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.chapter, required this.unit});
  final Chapter chapter;
  final Unit unit;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

enum _Phase { answering, correct, wrong, complete }

class _LessonScreenState extends State<LessonScreen>
    with TickerProviderStateMixin {
  late final List<MockQuestion> _questions;
  int _qIndex = 0;
  int? _selected;
  _Phase _phase = _Phase.answering;
  final List<bool> _results = [];

  late final AnimationController _feedbackCtrl;
  late final Animation<Offset> _feedbackSlide;
  late final AnimationController _xpCtrl;
  late final Animation<double> _xpFloat;

  @override
  void initState() {
    super.initState();
    _questions = MockData.questionsFor(widget.chapter.id);

    _feedbackCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _feedbackSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _feedbackCtrl, curve: Curves.easeOutCubic));

    _xpCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _xpFloat = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _xpCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    _xpCtrl.dispose();
    super.dispose();
  }

  MockQuestion get _current => _questions[_qIndex];
  int get _correctCount => _results.where((r) => r).length;

  int get _starsEarned {
    if (_results.isEmpty) return 0;
    final acc = _correctCount / _results.length;
    if (acc >= 0.99) return 3;
    if (acc >= 0.79) return 2;
    if (_correctCount > 0) return 1;
    return 0;
  }

  int get _xpEarned => _correctCount * 10;

  void _selectOption(int index) {
    if (_phase != _Phase.answering) return;
    setState(() => _selected = index);
  }

  void _checkAnswer() {
    if (_selected == null) return;
    final isCorrect = _selected == _current.correctIndex;
    _results.add(isCorrect);
    HapticFeedback.lightImpact();
    setState(() => _phase = isCorrect ? _Phase.correct : _Phase.wrong);
    _feedbackCtrl.forward(from: 0);
    if (isCorrect) _xpCtrl.forward(from: 0);
  }

  void _next() {
    _feedbackCtrl.reverse().then((_) {
      if (_qIndex < _questions.length - 1) {
        setState(() {
          _qIndex++;
          _selected = null;
          _phase = _Phase.answering;
        });
      } else {
        setState(() => _phase = _Phase.complete);
        HapticFeedback.mediumImpact();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = widget.unit.color;

    if (_phase == _Phase.complete) {
      return _CompletionScreen(
        chapter: widget.chapter,
        unit: widget.unit,
        stars: _starsEarned,
        xpEarned: _xpEarned,
        correctCount: _correctCount,
        totalCount: _results.length,
        onFinish: () => Navigator.of(context).pop(),
      );
    }

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _LessonTopBar(
                  current: _qIndex,
                  total: _questions.length,
                  color: color,
                  onClose: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SubjectChip(
                          label: _current.subject,
                          color: color,
                        ),
                        const SizedBox(height: 18),
                        _QuestionCard(question: _current.question),
                        const SizedBox(height: 24),
                        for (var i = 0; i < _current.options.length; i++) ...[
                          _AnswerOption(
                            label: _current.options[i],
                            index: i,
                            selected: _selected == i,
                            phase: _phase,
                            correct: _current.correctIndex == i,
                            onTap: () => _selectOption(i),
                          ),
                          const SizedBox(height: 10),
                        ],
                        // Space for the feedback panel
                        const SizedBox(height: 180),
                      ],
                    ),
                  ),
                ),
                // Check button
                if (_phase == _Phase.answering)
                  _CheckButton(
                    enabled: _selected != null,
                    color: color,
                    onTap: _checkAnswer,
                  ),
              ],
            ),
            // Feedback panel slides up
            if (_phase == _Phase.correct || _phase == _Phase.wrong)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SlideTransition(
                  position: _feedbackSlide,
                  child: _FeedbackPanel(
                    isCorrect: _phase == _Phase.correct,
                    correctAnswer: _current.options[_current.correctIndex],
                    explanation: _current.explanation,
                    onContinue: _next,
                  ),
                ),
              ),
            // Floating +XP badge
            if (_phase == _Phase.correct)
              AnimatedBuilder(
                animation: _xpFloat,
                builder: (context, _) => Positioned(
                  right: 24,
                  top: 80 + (1 - _xpFloat.value) * 24,
                  child: Opacity(
                    opacity: (1 - _xpFloat.value).clamp(0.0, 1.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '+10 XP',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
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

// ─── Lesson top bar ───────────────────────────────────────────────────────────
class _LessonTopBar extends StatelessWidget {
  const _LessonTopBar({
    required this.current,
    required this.total,
    required this.color,
    required this.onClose,
  });
  final int current, total;
  final Color color;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close_rounded, color: p.textSecondary),
            onPressed: onClose,
            tooltip: 'Exit lesson',
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (current) / total,
                minHeight: 10,
                backgroundColor: p.surfaceHigh,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$current / $total',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: p.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ─── Subject chip ─────────────────────────────────────────────────────────────
class _SubjectChip extends StatelessWidget {
  const _SubjectChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: text.labelMedium?.copyWith(
            color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Question card ────────────────────────────────────────────────────────────
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question});
  final String question;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.hairline, width: 0.5),
      ),
      child: Text(question, style: text.bodyLarge?.copyWith(height: 1.55)),
    );
  }
}

// ─── Answer option ────────────────────────────────────────────────────────────
class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.label,
    required this.index,
    required this.selected,
    required this.phase,
    required this.correct,
    required this.onTap,
  });
  final String label;
  final int index;
  final bool selected, correct;
  final _Phase phase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final bool revealed = phase == _Phase.correct || phase == _Phase.wrong;

    Color bg;
    Color borderColor;
    Color textColor;
    Widget? trailing;

    if (!revealed) {
      bg = selected ? p.accentSoft : p.surface;
      borderColor = selected ? p.accent : p.hairline;
      textColor = selected ? p.accent : p.textPrimary;
      trailing = null;
    } else if (correct) {
      bg = const Color(0xFF10B981).withValues(alpha: 0.15);
      borderColor = const Color(0xFF10B981);
      textColor = const Color(0xFF10B981);
      trailing = const Icon(Icons.check_circle_rounded,
          color: Color(0xFF10B981), size: 20);
    } else if (selected) {
      bg = const Color(0xFFEF4444).withValues(alpha: 0.12);
      borderColor = const Color(0xFFEF4444);
      textColor = const Color(0xFFEF4444);
      trailing = const Icon(Icons.cancel_rounded,
          color: Color(0xFFEF4444), size: 20);
    } else {
      bg = p.surface;
      borderColor = p.hairline;
      textColor = p.textTertiary;
      trailing = null;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: revealed ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: borderColor,
                width: selected || revealed ? 1.8 : 0.5,
              ),
            ),
            child: Row(
              children: [
                // Option letter
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: borderColor.withValues(alpha: 0.18),
                  ),
                  child: Center(
                    child: Text(
                      String.fromCharCode(65 + index), // A, B, C, D
                      style: text.labelMedium?.copyWith(
                        color: borderColor,
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
                      color: textColor,
                      fontWeight:
                          selected || correct ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Check button ─────────────────────────────────────────────────────────────
class _CheckButton extends StatelessWidget {
  const _CheckButton({
    required this.enabled,
    required this.color,
    required this.onTap,
  });
  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: enabled ? color : p.surfaceHigh,
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: Text(
                'Check answer',
                style: text.labelLarge?.copyWith(
                  color: enabled ? Colors.white : p.textTertiary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Feedback panel ───────────────────────────────────────────────────────────
class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({
    required this.isCorrect,
    required this.correctAnswer,
    required this.explanation,
    required this.onContinue,
  });
  final bool isCorrect;
  final String correctAnswer;
  final String explanation;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final Color panelColor = isCorrect
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
    final Color bg = isCorrect
        ? const Color(0xFF10B981).withValues(alpha: 0.12)
        : const Color(0xFFEF4444).withValues(alpha: 0.10);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(color: panelColor.withValues(alpha: 0.4), width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: panelColor,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                isCorrect ? 'Brilliant! ✨' : 'Nice try! 💪',
                style: text.titleMedium?.copyWith(color: panelColor),
              ),
            ],
          ),
          if (!isCorrect) ...[
            const SizedBox(height: 6),
            Text(
              'Correct: $correctAnswer',
              style: text.bodyMedium?.copyWith(
                color: panelColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            explanation,
            style: text.bodyMedium?.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: panelColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Continue',
                style: text.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Completion screen ────────────────────────────────────────────────────────
class _CompletionScreen extends StatefulWidget {
  const _CompletionScreen({
    required this.chapter,
    required this.unit,
    required this.stars,
    required this.xpEarned,
    required this.correctCount,
    required this.totalCount,
    required this.onFinish,
  });
  final Chapter chapter;
  final Unit unit;
  final int stars, xpEarned, correctCount, totalCount;
  final VoidCallback onFinish;

  @override
  State<_CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends State<_CompletionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scale = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.6)));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final color = widget.unit.color;
    final accuracy =
        widget.totalCount == 0 ? 0 : (widget.correctCount * 100) ~/ widget.totalCount;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              ScaleTransition(
                scale: _scale,
                child: FadeTransition(
                  opacity: _fade,
                  child: Column(
                    children: [
                      // Trophy circle
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: 0.15),
                          border: Border.all(color: color, width: 3),
                        ),
                        child: Center(
                          child: Text(
                            widget.stars >= 3
                                ? '🏆'
                                : widget.stars >= 2
                                    ? '🥈'
                                    : '🎯',
                            style: const TextStyle(fontSize: 42),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Lesson complete!', style: text.displayMedium),
                      const SizedBox(height: 8),
                      Text(
                        widget.chapter.title,
                        style: text.bodyLarge?.copyWith(color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 400 + i * 150),
                      curve: Curves.easeOutBack,
                      builder: (context, v, _) => Transform.scale(
                        scale: v,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            i < widget.stars
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: i < widget.stars
                                ? const Color(0xFFF59E0B)
                                : p.textTertiary,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 36),
              // Stats row
              Row(
                children: [
                  Expanded(
                    child: _StatBox(
                      value: '+${widget.xpEarned}',
                      label: 'XP earned',
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatBox(
                      value: '$accuracy%',
                      label: 'Accuracy',
                      color: accuracy >= 80
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatBox(
                      value: '${widget.correctCount}/${widget.totalCount}',
                      label: 'Correct',
                      color: p.textSecondary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: widget.onFinish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    'Back to learning',
                    style: text.titleMedium?.copyWith(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.value,
    required this.label,
    required this.color,
  });
  final String value, label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.hairline, width: 0.5),
      ),
      child: Column(
        children: [
          Text(value,
              style: text.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(label, style: text.labelSmall),
        ],
      ),
    );
  }
}
