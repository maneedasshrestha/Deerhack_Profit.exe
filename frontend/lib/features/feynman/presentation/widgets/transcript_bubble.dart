import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/transcript_entry.dart';
import 'jargon_text.dart';
import 'orb/feynman_orb.dart';

/// One chat-style turn in the transcript. Learner turns sit on the right with
/// inline jargon underlines; student turns sit on the left with a small orb
/// avatar and the reaction shown above the question.
class TranscriptBubble extends StatelessWidget {
  const TranscriptBubble({super.key, required this.entry});

  final TranscriptEntry entry;

  @override
  Widget build(BuildContext context) {
    return entry.isLearner ? _learner(context) : _student(context);
  }

  Widget _learner(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        child: Container(
          margin: const EdgeInsets.only(left: 48, bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: p.accentSoft,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
            border: Border.all(color: p.hairline, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              JargonText(
                text: entry.text,
                jargon: entry.jargon,
                style: text.bodyLarge,
              ),
              if (entry.clarity != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.show_chart_rounded, size: 13, color: p.textTertiary),
                    const SizedBox(width: 5),
                    Text('clarity ${entry.clarity}',
                        style: text.labelSmall?.copyWith(color: p.textTertiary)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _student(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.86),
        child: Padding(
          padding: const EdgeInsets.only(right: 32, bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: OrbBadge(size: 30),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(color: p.hairline, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (entry.reaction.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            entry.reaction,
                            style: text.bodyMedium?.copyWith(
                              color: p.textTertiary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      Text(entry.text, style: text.bodyLarge),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
