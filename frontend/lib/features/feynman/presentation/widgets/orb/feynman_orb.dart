import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../domain/models/feynman_phase.dart';
import 'orb_painter.dart';

/// The brand moment. A shader-driven (custom-painter) orb with three visually
/// distinct states and smooth transitions between them:
///
///   * idle      — nearly still, a slow shallow breath
///   * listening — expands/contracts with mic amplitude (driven by [level])
///   * thinking  — a gentle, different rhythm so a pause never reads as frozen
///   * speaking  — a slower, deeper "breathing" while the student talks
///
/// Concentric soft rings emanate outward on a slow loop to signal "live".
/// Honours reduce-motion by holding a calm steady state.
class FeynmanOrb extends StatefulWidget {
  const FeynmanOrb({
    super.key,
    required this.mode,
    required this.level,
    required this.reduceMotion,
    this.size = 280,
  });

  final OrbMode mode;

  /// Normalised 0..1 mic amplitude — only meaningful while listening.
  final double level;

  final bool reduceMotion;
  final double size;

  @override
  State<FeynmanOrb> createState() => _FeynmanOrbState();
}

class _FeynmanOrbState extends State<FeynmanOrb> with TickerProviderStateMixin {
  late final AnimationController _loop; // continuous phase for rings + breath

  // Smoothly interpolated values so transitions between states glide.
  double _displayLevel = 0;
  double _activation = 0; // 0 idle … 1 fully active, eases between modes

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7200),
    );
    if (!widget.reduceMotion) _loop.repeat();
  }

  @override
  void didUpdateWidget(covariant FeynmanOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduceMotion != oldWidget.reduceMotion) {
      if (widget.reduceMotion) {
        _loop.stop();
      } else if (!_loop.isAnimating) {
        _loop.repeat();
      }
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  double get _targetActivation => switch (widget.mode) {
        OrbMode.idle => 0.0,
        OrbMode.listening => 1.0,
        OrbMode.thinking => 0.55,
        OrbMode.speaking => 0.8,
      };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _loop,
        builder: (context, _) {
          // Ease the per-frame values toward their targets (frame-rate-ish).
          _displayLevel += (widget.level - _displayLevel) * 0.18;
          _activation += (_targetActivation - _activation) * 0.10;

          return CustomPaint(
            size: Size.square(widget.size),
            painter: OrbPainter(
              phase: _loop.value,
              mode: widget.mode,
              level: _displayLevel,
              activation: _activation,
              reduceMotion: widget.reduceMotion,
              core: p.orbCore,
              glow: p.orbGlow,
              accent: p.accent,
              ring: p.accentSoft,
            ),
          );
        },
      ),
    );
  }
}

/// A compact, non-interactive orb used as a thumbnail / hero target in the
/// reflection header. Same look, no continuous animation needed.
class OrbBadge extends StatelessWidget {
  const OrbBadge({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CustomPaint(
      size: Size.square(size),
      painter: OrbPainter(
        phase: 0.2,
        mode: OrbMode.idle,
        level: 0,
        activation: 0.3,
        reduceMotion: true,
        core: p.orbCore,
        glow: p.orbGlow,
        accent: p.accent,
        ring: p.accentSoft,
        rings: 1,
      ),
    );
  }
}

/// Exposed for tests / tuning — the breathing curve used by the painter.
double orbBreath(double phase, double speed) =>
    0.5 + 0.5 * math.sin(phase * 2 * math.pi * speed);
