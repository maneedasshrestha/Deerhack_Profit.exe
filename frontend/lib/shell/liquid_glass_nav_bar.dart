import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// One destination in the [LiquidGlassNavBar].
class GlassNavItem {
  const GlassNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// A floating "liquid glass" bottom navigation bar.
///
/// Renders a frosted, translucent pill that sits *above* the content (use with
/// `Scaffold.extendBody: true`) so the [BackdropFilter] genuinely blurs whatever
/// scrolls behind it. The active tab is marked by a soft accent pill that glides
/// between slots, and each icon gives a little spring as it becomes selected.
///
/// Visual recipe for the glass: a top-lit gradient fill (a faint sheen up top
/// fading down), a bright hairline rim that reads as the edge of a glass panel,
/// and a soft drop shadow plus a subtle accent glow to lift it off the page.
class LiquidGlassNavBar extends StatelessWidget {
  const LiquidGlassNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<GlassNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Bar height (excluding the surrounding margin / safe-area inset).
  static const double barHeight = 74;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dark = p.isDark;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        0,
        18,
        bottomInset > 0 ? bottomInset : 16,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: Container(
            height: barHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              // Top-lit sheen fading downward — the core of the glass look.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dark
                    ? [
                        Colors.white.withValues(alpha: 0.14),
                        Colors.white.withValues(alpha: 0.04),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.78),
                        Colors.white.withValues(alpha: 0.48),
                      ],
              ),
              // Bright rim = the edge of the glass.
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.85),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.45 : 0.14),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: p.accent.withValues(alpha: dark ? 0.20 : 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, c) {
                final slot = c.maxWidth / items.length;
                return Stack(
                  children: [
                    // The gliding accent pill behind the active destination.
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 340),
                      curve: Curves.easeOutCubic,
                      left: slot * selectedIndex + 12,
                      top: 9,
                      bottom: 9,
                      width: slot - 24,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: p.accent.withValues(alpha: dark ? 0.24 : 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: p.accent.withValues(alpha: 0.32),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(
                            child: _NavButton(
                              item: items[i],
                              selected: i == selectedIndex,
                              onTap: () => onSelected(i),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = selected ? p.accent : p.textTertiary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedScale(
            scale: selected ? 1.14 : 1.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            child: Icon(item.icon, size: 28, color: color),
          ),
        ),
      ),
    );
  }
}
