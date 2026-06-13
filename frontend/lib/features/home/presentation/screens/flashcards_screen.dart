import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../domain/plan_data.dart';

// ═══════════════════════════════════════════════════════════════════════════
// FlashcardsScreen — the bonus level. Tinder-style true/false cards for
// formulas and quick facts: swipe right for TRUE, left for FALSE. Built for
// spaced repetition — fast, tactile, satisfying.
// ═══════════════════════════════════════════════════════════════════════════
class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key, this.onCompleted});

  /// Called when the deck is finished — lets the week map mark the bonus done.
  final VoidCallback? onCompleted;

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen>
    with SingleTickerProviderStateMixin {
  final List<Flashcard> _cards = PlanData.formulaCards;
  int _index = 0;
  int _correct = 0;

  Offset _drag = Offset.zero;
  late final AnimationController _fling;
  Animation<Offset>? _flingAnim;
  bool? _lastWasCorrect;
  Flashcard? _lastCard;

  @override
  void initState() {
    super.initState();
    _fling = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _fling.dispose();
    super.dispose();
  }

  bool get _done => _index >= _cards.length;
  Flashcard get _card => _cards[_index];

  void _onPanUpdate(DragUpdateDetails d) {
    if (_fling.isAnimating) return;
    setState(() => _drag += d.delta);
  }

  void _onPanEnd(DragEndDetails d, double width) {
    if (_fling.isAnimating) return;
    const threshold = 90.0;
    if (_drag.dx.abs() > threshold) {
      _commitSwipe(_drag.dx > 0, width);
    } else {
      // Spring back to centre.
      _flingAnim = Tween<Offset>(begin: _drag, end: Offset.zero).animate(
          CurvedAnimation(parent: _fling, curve: Curves.easeOutBack));
      _fling.forward(from: 0).then((_) {
        if (!mounted) return;
        setState(() {
          _drag = Offset.zero;
          _flingAnim = null;
        });
        _fling.reset();
      });
    }
  }

  void _commitSwipe(bool answeredTrue, double width) {
    final card = _card;
    final isCorrect = answeredTrue == card.isTrue;
    HapticFeedback.mediumImpact();
    setState(() {
      _lastWasCorrect = isCorrect;
      _lastCard = card;
      if (isCorrect) _correct++;
    });
    final exitX = (answeredTrue ? 1 : -1) * (width * 1.3);
    _flingAnim = Tween<Offset>(
      begin: _drag,
      end: Offset(exitX, _drag.dy * 1.4),
    ).animate(CurvedAnimation(parent: _fling, curve: Curves.easeIn));
    _fling.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _drag = Offset.zero;
        _flingAnim = null;
        _index++;
      });
      _fling.reset();
    });
  }

  /// Button fallback for tap-preferring users — same path as a full swipe.
  void _answerWithButton(bool answeredTrue) {
    if (_fling.isAnimating || _done) return;
    _commitSwipe(answeredTrue, MediaQuery.sizeOf(context).width);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    if (_done) {
      return _DeckCompleteView(
        correct: _correct,
        total: _cards.length,
        onFinish: () {
          widget.onCompleted?.call();
          Navigator.of(context).pop();
        },
      );
    }

    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: p.textSecondary),
                    tooltip: 'Exit',
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _index / _cards.length,
                        minHeight: 12,
                        backgroundColor: p.surfaceHigh,
                        valueColor:
                            const AlwaysStoppedAnimation(Color(0xFFEC4899)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${_index + 1}/${_cards.length}',
                      style: text.labelMedium),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('Formula flash',
                style: text.headlineSmall?.copyWith(fontSize: 20)),
            Text(
              'Swipe right if it\'s true, left if it\'s false',
              style: text.labelMedium?.copyWith(color: p.textTertiary),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: _fling,
                builder: (context, _) {
                  final off = _flingAnim?.value ?? _drag;
                  final prog = (off.dx / width).clamp(-1.0, 1.0);
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Next card peeks from underneath, scaling up as the
                      // top card leaves.
                      if (_index + 1 < _cards.length)
                        Transform.scale(
                          scale: 0.93 + 0.07 * prog.abs(),
                          child: _CardFace(
                              card: _cards[_index + 1], dimmed: true),
                        ),
                      GestureDetector(
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: (d) => _onPanEnd(d, width),
                        child: Transform.translate(
                          offset: off,
                          child: Transform.rotate(
                            angle: prog * 0.18,
                            child: _CardFace(
                              card: _card,
                              stampProgress: prog,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // Feedback strip for the previous card.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _lastCard == null
                  ? const SizedBox(height: 52)
                  : Container(
                      key: ValueKey('${_lastCard!.id}-$_lastWasCorrect'),
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: (_lastWasCorrect!
                                ? const Color(0xFF059669)
                                : const Color(0xFFE11D48))
                            .withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _lastWasCorrect!
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            size: 18,
                            color: _lastWasCorrect!
                                ? const Color(0xFF059669)
                                : const Color(0xFFE11D48),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _lastCard!.note,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelMedium
                                  ?.copyWith(color: p.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            // Tap fallback buttons.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'False',
                      icon: Icons.close_rounded,
                      color: const Color(0xFFE11D48),
                      tonal: true,
                      onTap: () => _answerWithButton(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: 'True',
                      icon: Icons.check_rounded,
                      color: const Color(0xFF059669),
                      tonal: true,
                      onTap: () => _answerWithButton(true),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Card face ────────────────────────────────────────────────────────────────
/// Subject-tinted gradients within the purple family so the deck has
/// character but still belongs to the app.
(List<Color>, IconData) _styleFor(String subject) => switch (subject) {
      'Physics' => (
          [const Color(0xFF6D5BE0), const Color(0xFF8B7CF6)],
          Icons.bolt_rounded
        ),
      'Maths' => (
          [const Color(0xFF7C3AED), const Color(0xFFA855F7)],
          Icons.functions_rounded
        ),
      'Chemistry' => (
          [const Color(0xFF8B5CF6), const Color(0xFFD946EF)],
          Icons.science_rounded
        ),
      _ => (
          [const Color(0xFF9333EA), const Color(0xFFEC4899)],
          Icons.menu_book_rounded
        ),
    };

class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.card,
    this.stampProgress = 0,
    this.dimmed = false,
  });

  final Flashcard card;

  /// −1…1: how far the card has been dragged (negative = FALSE side).
  final double stampProgress;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (colors, watermark) = _styleFor(card.subject);

    return Container(
      width: 300,
      height: 380,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dimmed
              ? [for (final c in colors) c.withValues(alpha: 0.45)]
              : colors,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: dimmed ? 0.10 : 0.35),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Oversized watermark icon gives the card its character.
            Positioned(
              right: -34,
              bottom: -30,
              child: Transform.rotate(
                angle: -0.25,
                child: Icon(
                  watermark,
                  size: 190,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ),
            // A second, smaller echo top-left for balance.
            Positioned(
              left: -18,
              top: -14,
              child: Icon(
                watermark,
                size: 90,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(watermark, size: 13, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          card.subject,
                          style: text.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Center(
                    child: Text(
                      card.statement,
                      textAlign: TextAlign.center,
                      style: text.headlineSmall?.copyWith(
                        color: Colors.white,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swipe_rounded,
                            size: 15,
                            color: Colors.white.withValues(alpha: 0.75)),
                        const SizedBox(width: 6),
                        Text(
                          'true or false?',
                          style: text.labelSmall?.copyWith(
                              color:
                                  Colors.white.withValues(alpha: 0.75)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // TRUE stamp (right swipe)
            if (stampProgress > 0.05)
              Positioned(
                top: 22,
                left: 22,
                child: _Stamp(
                  label: 'TRUE',
                  color: const Color(0xFF059669),
                  opacity: (stampProgress * 2).clamp(0.0, 1.0),
                  angle: -0.25,
                ),
              ),
            // FALSE stamp (left swipe)
            if (stampProgress < -0.05)
              Positioned(
                top: 22,
                right: 22,
                child: _Stamp(
                  label: 'FALSE',
                  color: const Color(0xFFE11D48),
                  opacity: (-stampProgress * 2).clamp(0.0, 1.0),
                  angle: 0.25,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({
    required this.label,
    required this.color,
    required this.opacity,
    required this.angle,
  });

  final String label;
  final Color color;
  final double opacity;
  final double angle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Opacity(
      opacity: opacity,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 3),
          ),
          child: Text(
            label,
            style: text.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Deck complete ────────────────────────────────────────────────────────────
class _DeckCompleteView extends StatelessWidget {
  const _DeckCompleteView({
    required this.correct,
    required this.total,
    required this.onFinish,
  });

  final int correct, total;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final pct = total == 0 ? 0 : (correct * 100) ~/ total;

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
                  progress: pct / 100,
                  size: 132,
                  strokeWidth: 10,
                  color: const Color(0xFFEC4899),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$correct/$total',
                          style: text.displayMedium?.copyWith(
                              color: const Color(0xFFEC4899), fontSize: 30)),
                      Text('recalled', style: text.labelSmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              StaggeredEntrance(
                index: 1,
                child: Text('Deck cleared!', style: text.displayMedium),
              ),
              const SizedBox(height: 8),
              StaggeredEntrance(
                index: 2,
                child: Text(
                  'These cards will resurface over the coming days — that\'s '
                  'the spaced repetition doing its job.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium,
                ),
              ),
              const Spacer(),
              AppButton(
                label: 'Back to my week',
                color: const Color(0xFFEC4899),
                onTap: onFinish,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
