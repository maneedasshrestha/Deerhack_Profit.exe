import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion.dart';

/// A self-contained confetti burst — no plugin, just a [CustomPainter] driven by
/// one [AnimationController]. Drop it on top of a screen (inside a [Stack]) and
/// it rains festive paper from the top, flipping and swaying as it falls, then
/// fades out. Honours "reduce motion": it renders nothing when animations are
/// minimised. It never intercepts touches.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({
    super.key,
    this.particleCount = 150,
    this.duration = const Duration(milliseconds: 3000),
    this.colors,
    this.autoPlay = true,
  });

  final int particleCount;
  final Duration duration;

  /// Confetti palette. Defaults to a warm, celebratory spread.
  final List<Color>? colors;

  /// Start falling as soon as the widget mounts.
  final bool autoPlay;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  static const List<Color> _defaultColors = [
    Color(0xFFF97316), // orange — the streak flame
    Color(0xFFFBBF24), // amber
    Color(0xFF34D399), // emerald
    Color(0xFF60A5FA), // sky
    Color(0xFFF472B6), // pink
    Color(0xFFA78BFA), // violet
  ];

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);
  late final List<_Confetto> _confetti;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(7);
    final colors = widget.colors ?? _defaultColors;
    _confetti = List.generate(widget.particleCount, (i) {
      return _Confetto(
        startX: rng.nextDouble(),
        // A short staggered entry so the burst reads as a shower, not a wall.
        delay: rng.nextDouble() * 0.28,
        fall: 1.0 + rng.nextDouble() * 0.7,
        sway: 14 + rng.nextDouble() * 30,
        swayFreq: 2 + rng.nextDouble() * 4,
        phase: rng.nextDouble() * math.pi * 2,
        size: 7 + rng.nextDouble() * 7,
        rotation: rng.nextDouble() * math.pi * 2,
        rotationSpeed: (rng.nextDouble() - 0.5) * 14,
        color: colors[rng.nextInt(colors.length)],
        round: rng.nextBool(),
      );
    });
    if (widget.autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !context.reduceMotion) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Replay the burst from the start.
  void play() => _controller.forward(from: 0);

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(
              confetti: _confetti,
              progress: _controller.value,
            ),
          ),
        ),
      ),
    );
  }
}

/// One piece of paper. All positions are normalised (0–1 across the width / a
/// fall multiple of the height) so a single set works at any screen size.
class _Confetto {
  _Confetto({
    required this.startX,
    required this.delay,
    required this.fall,
    required this.sway,
    required this.swayFreq,
    required this.phase,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.color,
    required this.round,
  });

  final double startX;
  final double delay;
  final double fall;
  final double sway;
  final double swayFreq;
  final double phase;
  final double size;
  final double rotation;
  final double rotationSpeed;
  final Color color;
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.confetti, required this.progress});

  final List<_Confetto> confetti;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()..style = PaintingStyle.fill;

    for (final c in confetti) {
      // Per-particle local time, post-delay, renormalised to 0–1.
      final span = 1 - c.delay;
      final t = ((progress - c.delay) / span).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final x = size.width * c.startX +
          c.sway * math.sin(t * c.swayFreq + c.phase);
      final y = -20 + (size.height + 60) * (t * c.fall);
      if (y > size.height + 30) continue;

      // Fade out over the last quarter of the fall.
      final opacity = t < 0.75 ? 1.0 : (1 - (t - 0.75) / 0.25).clamp(0.0, 1.0);
      final angle = c.rotation + c.rotationSpeed * t;
      // Squash the height by the rotation to fake a 3-D flutter/flip.
      final flip = (0.35 + 0.65 * math.sin(angle).abs());

      paint.color = c.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      if (c.round) {
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset.zero, width: c.size, height: c.size * flip),
          paint,
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: c.size, height: c.size * flip),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
