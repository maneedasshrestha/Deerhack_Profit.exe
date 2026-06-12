import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Depth through layering, not heavy shadows: a translucent surface with a
/// 0.5px hairline border and a light backdrop blur where it reads as glass.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.blur = 18,
    this.opacity = 0.7,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final border = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: border,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: p.surfaceHigh.withValues(alpha: opacity),
            borderRadius: border,
            border: Border.all(color: p.hairline, width: 0.5),
          ),
          child: child,
        ),
      ),
    );
  }
}
