import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// The single line of live caption shown center-bottom while listening — the one
/// concession that keeps reflection alive even in voice mode. New words fade in
/// one at a time. Doubles as an accessibility live region.
class LiveCaption extends StatelessWidget {
  const LiveCaption({super.key, required this.text, this.dimmed = false});

  final String text;

  /// When true (e.g. while the student speaks), the caption is shown muted.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: dimmed ? p.textTertiary : p.textPrimary,
          height: 1.35,
        );
    final words = text.trim().isEmpty ? const <String>[] : text.trim().split(RegExp(r'\s+'));

    return Semantics(
      liveRegion: true,
      label: text,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: words.isEmpty
            ? const SizedBox(height: 0, width: double.infinity)
            : Wrap(
                key: ValueKey(words.length),
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 2,
                children: [
                  for (var i = 0; i < words.length; i++)
                    _FadeWord(
                      // Keying by index+word means only newly-added words animate.
                      key: ValueKey('$i:${words[i]}'),
                      child: Text(words[i], style: style),
                    ),
                ],
              ),
      ),
    );
  }
}

class _FadeWord extends StatelessWidget {
  const _FadeWord({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // TweenAnimationBuilder animates 0→1 once when this word is first inserted.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 6), child: child),
      ),
      child: child,
    );
  }
}
