import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/haptics.dart';
import '../../../../core/motion.dart';
import '../../../../core/widgets/confetti_overlay.dart';
import '../../../../core/widgets/ui_kit.dart';

/// The Duolingo-style payoff after a day's MCQs: a warm full-screen moment with
/// confetti, a flame that springs in, the streak number rolling up to its new
/// value, and a week strip ticking the day complete.
///
/// Drive it from a completion flow:
/// ```dart
/// final from = ref.read(streakProvider.notifier).registerDayComplete();
/// final to = ref.read(streakProvider);
/// Navigator.of(context).push(MaterialPageRoute(
///   builder: (_) => StreakCelebrationScreen(fromStreak: from, toStreak: to),
/// ));
/// ```
class StreakCelebrationScreen extends StatefulWidget {
  const StreakCelebrationScreen({
    super.key,
    required this.fromStreak,
    required this.toStreak,
    this.onContinue,
  });

  /// Streak before today's practice.
  final int fromStreak;

  /// Streak after — equal to [fromStreak] if the day was already counted.
  final int toStreak;

  /// Called when the learner taps continue. Defaults to popping this screen.
  final VoidCallback? onContinue;

  @override
  State<StreakCelebrationScreen> createState() =>
      _StreakCelebrationScreenState();
}

class _StreakCelebrationScreenState extends State<StreakCelebrationScreen>
    with SingleTickerProviderStateMixin {
  static const _flame = Color(0xFFF97316);
  static const _flameDeep = Color(0xFFEA580C);

  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  late int _display = widget.fromStreak;
  bool _rolled = false;

  bool get _increased => widget.toStreak > widget.fromStreak;

  @override
  void initState() {
    super.initState();
    _c.addListener(_maybeRoll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Haptics.sessionEnd();
      if (context.reduceMotion) {
        setState(() => _display = widget.toStreak);
        _c.value = 1;
      } else {
        _c.forward();
      }
    });
  }

  /// Flip the displayed number to the new value partway through, so the roll
  /// lands just as the flame finishes springing in.
  void _maybeRoll() {
    if (!_rolled && _c.value >= 0.42) {
      _rolled = true;
      if (_increased) HapticFeedback.mediumImpact();
      setState(() => _display = widget.toStreak);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _continue() {
    if (widget.onContinue != null) {
      widget.onContinue!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final daysLit = widget.toStreak.clamp(0, 7);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_flame, _flameDeep],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: _continue,
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white70),
                      ),
                    ),
                    const Spacer(),
                    _Flame(controller: _c),
                    const SizedBox(height: 8),
                    _StreakNumber(value: _display, controller: _c),
                    const SizedBox(height: 2),
                    _fade(
                      0.3,
                      Text(
                        'day streak!',
                        style: text.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _fade(
                      0.5,
                      _WeekStrip(daysLit: daysLit, controller: _c),
                    ),
                    const SizedBox(height: 22),
                    _fade(
                      0.6,
                      Text(
                        _increased
                            ? 'You showed up today. Come back tomorrow to '
                                'keep the flame alive.'
                            : 'Today is already in the bag — your streak is '
                                'safe. Nice consistency.',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _fade(
                      0.7,
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          label: 'Continue',
                          color: Colors.white,
                          tonal: true,
                          onTap: _continue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Confetti rides above everything but never blocks the button.
            const Positioned.fill(child: ConfettiOverlay()),
          ],
        ),
      ),
    );
  }

  /// Fade + lift a child in, gated on a point in the master timeline.
  Widget _fade(double start, Widget child) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = ((_c.value - start) / (1 - start)).clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
        );
      },
      child: child,
    );
  }
}

/// The flame badge: springs up from nothing, then breathes gently.
class _Flame extends StatelessWidget {
  const _Flame({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final v = controller.value;
        final pop = Curves.elasticOut
            .transform((v / 0.4).clamp(0.0, 1.0));
        // A subtle continuous breathe once it has landed.
        final breathe = v > 0.4 ? 1 + 0.03 * math.sin(v * math.pi * 6) : 1.0;
        return Transform.scale(
          scale: pop * breathe,
          child: Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.16),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.25),
                  blurRadius: 36,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.local_fire_department_rounded,
                color: Colors.white, size: 84),
          ),
        );
      },
    );
  }
}

/// The big streak count. The number itself rolls over with a slide+fade when it
/// changes, and the whole figure gives a spring "pop" as the new value lands.
class _StreakNumber extends StatelessWidget {
  const _StreakNumber({required this.value, required this.controller});
  final int value;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final pop = 1 +
            0.18 *
                Curves.elasticOut
                    .transform(((controller.value - 0.42) / 0.4).clamp(0.0, 1.0)) *
                (1 - ((controller.value - 0.42) / 0.4).clamp(0.0, 1.0));
        return Transform.scale(scale: pop, child: child);
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        transitionBuilder: (child, anim) {
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.55),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack));
          return ClipRect(
            child: SlideTransition(
              position: slide,
              child: FadeTransition(opacity: anim, child: child),
            ),
          );
        },
        child: Text(
          '$value',
          key: ValueKey(value),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 104,
            height: 1.0,
            fontWeight: FontWeight.w900,
            letterSpacing: -2,
          ),
        ),
      ),
    );
  }
}

/// A seven-day strip. Days within the streak light up; the most recent (today)
/// pops in last with a flame.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.daysLit, required this.controller});

  final int daysLit;
  final AnimationController controller;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < 7; i++)
            Builder(builder: (context) {
              final lit = i >= 7 - daysLit;
              final isToday = i == 6;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _labels[i],
                    style: text.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) {
                      // Today's pip springs in on the back half of the timeline.
                      final pop = isToday
                          ? Curves.elasticOut.transform(
                              ((controller.value - 0.55) / 0.45)
                                  .clamp(0.0, 1.0))
                          : 1.0;
                      return Transform.scale(
                        scale: isToday ? pop : 1.0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: lit
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.22),
                          ),
                          child: lit
                              ? Icon(
                                  isToday
                                      ? Icons.local_fire_department_rounded
                                      : Icons.check_rounded,
                                  size: 17,
                                  color: const Color(0xFFEA580C),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }
}
