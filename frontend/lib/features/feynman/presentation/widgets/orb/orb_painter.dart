import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/models/feynman_phase.dart';

/// Draws the orb. All look-and-feel lives here so [FeynmanOrb] stays a thin
/// driver. The painter is intentionally layered for depth:
///   1. emanating concentric rings (the "live" signal)
///   2. an ambient outer glow (blurred)
///   3. the core sphere with a radial gradient
///   4. an off-centre inner highlight for dimensionality
class OrbPainter extends CustomPainter {
  OrbPainter({
    required this.phase,
    required this.mode,
    required this.level,
    required this.activation,
    required this.reduceMotion,
    required this.core,
    required this.glow,
    required this.accent,
    required this.ring,
    this.rings = 3,
  });

  /// 0..1 continuous loop phase.
  final double phase;
  final OrbMode mode;

  /// Smoothed 0..1 mic amplitude.
  final double level;

  /// 0 idle … 1 active, eased between modes.
  final double activation;

  final bool reduceMotion;
  final Color core;
  final Color glow;
  final Color accent;
  final Color ring;
  final int rings;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    final baseR = maxR * 0.46;

    // Per-mode scale of the core. Each state has a distinct rhythm.
    final breathSlow = math.sin(phase * 2 * math.pi);
    final breathFast = math.sin(phase * 2 * math.pi * 1.6);

    double scale;
    switch (mode) {
      case OrbMode.idle:
        scale = 1.0 + (reduceMotion ? 0 : 0.02 * breathSlow);
      case OrbMode.listening:
        // Amplitude-reactive: the orb grows and contracts with the voice.
        final pulse = reduceMotion ? 0 : 0.04 * breathFast;
        scale = 1.0 + 0.06 + level * 0.5 + pulse;
      case OrbMode.thinking:
        // A gentle, slightly faster shimmer so the pause never reads as frozen.
        scale = 1.0 + (reduceMotion ? 0.04 : 0.06 + 0.05 * breathFast);
      case OrbMode.speaking:
        // A deeper, slower breath — clearly different from the listening pulse.
        scale = 1.0 + (reduceMotion ? 0.06 : 0.10 + 0.10 * breathSlow);
    }

    final r = baseR * scale;

    _paintRings(canvas, center, baseR, maxR);
    _paintAmbientGlow(canvas, center, r);
    _paintCore(canvas, center, r);
    _paintHighlight(canvas, center, r);
  }

  void _paintRings(Canvas canvas, Offset center, double baseR, double maxR) {
    if (reduceMotion && rings > 1) {
      // Static faint ring instead of a moving loop.
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = ring.withValues(alpha: ring.a * 0.5);
      canvas.drawCircle(center, baseR * 1.5, paint);
      return;
    }

    for (var i = 0; i < rings; i++) {
      final progress = (phase + i / rings) % 1.0;
      final ringR = baseR * (1.05 + progress * 1.15);
      // Brighten with activation; fade as the ring expands.
      final fade = (1.0 - progress);
      final alpha = ring.a * fade * fade * (0.35 + 0.65 * activation);
      if (alpha <= 0.01) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 + 1.4 * fade
        ..color = ring.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(center, ringR, paint);
    }
  }

  void _paintAmbientGlow(Canvas canvas, Offset center, double r) {
    final glowStrength = 0.18 + 0.32 * activation;
    final paint = Paint()
      ..color = glow.withValues(alpha: glowStrength)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.55);
    canvas.drawCircle(center, r * 0.92, paint);
  }

  void _paintCore(Canvas canvas, Offset center, double r) {
    final gradient = RadialGradient(
      colors: [
        Color.lerp(core, Colors.white, 0.25 * activation)!,
        core,
        glow,
        glow.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.45, 0.86, 1.0],
    );
    final rect = Rect.fromCircle(center: center, radius: r);
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawCircle(center, r, paint);

    // A crisp inner disc keeps the orb from looking purely like a blur.
    final disc = Paint()
      ..shader = RadialGradient(
        colors: [
          core.withValues(alpha: 0.0),
          glow.withValues(alpha: 0.22),
        ],
        stops: const [0.55, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, r, disc);
  }

  void _paintHighlight(Canvas canvas, Offset center, double r) {
    // Off-centre highlight for a sense of volume; drifts slowly with the loop.
    final drift = reduceMotion ? 0.0 : math.sin(phase * 2 * math.pi * 0.5);
    final hl = center.translate(-r * 0.28, -r * (0.30 + 0.04 * drift));
    final rect = Rect.fromCircle(center: hl, radius: r * 0.5);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.30 + 0.15 * activation),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(rect)
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(hl, r * 0.5, paint);
  }

  @override
  bool shouldRepaint(covariant OrbPainter old) =>
      old.phase != phase ||
      old.level != level ||
      old.activation != activation ||
      old.mode != mode ||
      old.reduceMotion != reduceMotion;
}
