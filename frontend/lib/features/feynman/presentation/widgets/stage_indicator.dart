import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// The three-stage progress indicator: 1 Explain → 2 Gaps → 3 Simplify.
/// The active stage is highlighted with the accent; completed stages get a
/// check. Sentence case throughout.
class StageIndicator extends StatelessWidget {
  const StageIndicator({super.key, required this.activeStage});

  /// 0 = explain, 1 = gaps, 2 = simplify.
  final int activeStage;

  static const _labels = ['Explain', 'Gaps', 'Simplify'];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: 'Stage ${activeStage + 1} of 3: ${_labels[activeStage]}',
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            _Stage(
              index: i,
              label: _labels[i],
              done: i < activeStage,
              active: i == activeStage,
            ),
            if (i < 2)
              Expanded(
                child: Container(
                  height: 1.5,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: i < activeStage ? p.accent : p.hairline,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({
    required this.index,
    required this.label,
    required this.done,
    required this.active,
  });

  final int index;
  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final accent = active || done;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent ? p.accent : Colors.transparent,
            border: Border.all(
              color: accent ? p.accent : p.textTertiary,
              width: 1.4,
            ),
          ),
          alignment: Alignment.center,
          child: done
              ? const Icon(Icons.check, size: 13, color: Colors.white)
              : Text(
                  '${index + 1}',
                  style: text.labelSmall?.copyWith(
                    color: active ? Colors.white : p.textTertiary,
                  ),
                ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: text.labelMedium?.copyWith(
            color: accent ? p.textPrimary : p.textTertiary,
          ),
        ),
      ],
    );
  }
}
