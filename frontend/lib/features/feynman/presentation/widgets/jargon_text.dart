import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Renders the learner's own words with any flagged jargon underlined inline
/// (wavy underline, warning accent) so they see exactly where abstraction crept
/// in. Colour is never the sole signal: each flagged term also carries a small
/// warning glyph, and exposes a semantics label.
class JargonText extends StatelessWidget {
  const JargonText({
    super.key,
    required this.text,
    required this.jargon,
    this.style,
  });

  final String text;
  final List<String> jargon;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final base = style ?? Theme.of(context).textTheme.bodyLarge!;
    if (jargon.isEmpty) {
      return Text(text, style: base);
    }

    final spans = <InlineSpan>[];
    final lower = text.toLowerCase();
    // Find every occurrence of every term; mark the covered ranges.
    final marks = List<bool>.filled(text.length, false);
    for (final term in jargon) {
      final t = term.toLowerCase().trim();
      if (t.isEmpty) continue;
      var from = 0;
      while (true) {
        final idx = lower.indexOf(t, from);
        if (idx < 0) break;
        for (var i = idx; i < idx + t.length && i < marks.length; i++) {
          marks[i] = true;
        }
        from = idx + t.length;
      }
    }

    // Walk the string, grouping consecutive marked / unmarked runs.
    var i = 0;
    while (i < text.length) {
      final marked = marks[i];
      final start = i;
      while (i < text.length && marks[i] == marked) {
        i++;
      }
      final chunk = text.substring(start, i);
      if (marked) {
        spans.add(TextSpan(
          text: chunk,
          style: base.copyWith(
            color: p.warning,
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.wavy,
            decorationColor: p.warning,
          ),
        ));
        // Small warning glyph so colour isn't the only cue.
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(left: 2, right: 1),
            child: Icon(Icons.warning_amber_rounded, size: 13, color: p.warning),
          ),
        ));
      } else {
        spans.add(TextSpan(text: chunk, style: base));
      }
    }

    return Semantics(
      label: 'Explanation with ${jargon.length} flagged jargon terms: $text',
      child: ExcludeSemantics(child: Text.rich(TextSpan(children: spans))),
    );
  }
}
