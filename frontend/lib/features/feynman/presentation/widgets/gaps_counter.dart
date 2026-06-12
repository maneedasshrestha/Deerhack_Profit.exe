import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'glass_panel.dart';

/// The subtle "N gaps noticed" counter on the live screen's bottom bar. Taps
/// through to the transcript. The number ticks with a quick scale pop when it
/// changes.
class GapsCounter extends StatelessWidget {
  const GapsCounter({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final label = count == 1 ? '1 gap noticed' : '$count gaps noticed';
    return Semantics(
      button: true,
      label: '$label. Opens the transcript.',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          radius: 22,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                count > 0 ? Icons.lightbulb_outline_rounded : Icons.check_circle_outline,
                size: 16,
                color: count > 0 ? p.warning : p.positive,
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: Tween(begin: 0.7, end: 1.0).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Text(
                  label,
                  key: ValueKey(count),
                  style: text.labelMedium?.copyWith(color: p.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
