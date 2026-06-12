import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// The single prominent action style — accent fill, confident, springy press.
/// Used sparingly (start session, teach again) per the one-accent rule.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expand;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = widget.onPressed != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _scale = 0.96) : null,
      onTapUp: enabled ? (_) => setState(() => _scale = 1) : null,
      onTapCancel: enabled ? () => setState(() => _scale = 1) : null,
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: widget.expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: enabled ? p.accent : p.surfaceHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon,
                    size: 19, color: enabled ? Colors.white : p.textTertiary),
                const SizedBox(width: 9),
              ],
              Text(
                widget.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: enabled ? Colors.white : p.textTertiary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
