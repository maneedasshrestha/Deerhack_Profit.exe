import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../application/study_providers.dart';
import '../../domain/mock_data.dart';

/// A compact, tap-to-reveal MCQ tile reused by the week-detail and question-bank
/// screens. Tapping the body reveals the correct answer and explanation; the
/// star toggles the question into the learner's starred set for revision.
///
/// A subject-coloured spine down the left edge ties each tile to its subject and
/// gives the otherwise-plain list some character.
class QuestionTile extends ConsumerStatefulWidget {
  const QuestionTile({super.key, required this.question, this.accent});

  final MockQuestion question;

  /// Subject accent for the chip + spine; falls back to the app accent.
  final Color? accent;

  @override
  ConsumerState<QuestionTile> createState() => _QuestionTileState();
}

class _QuestionTileState extends ConsumerState<QuestionTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final q = widget.question;
    final accent = widget.accent ?? p.accent;
    final starred = ref.watch(starredQuestionsProvider).contains(q.id);

    return Pressable(
      onTap: () => setState(() => _open = !_open),
      scale: 0.99,
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2A2150).withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          // A Stack (rather than an IntrinsicHeight Row) keeps the spine
          // full-height without fighting the answer's collapse animation —
          // IntrinsicHeight would snap to the collapsed height instantly while
          // AnimatedSize is still shrinking, briefly overflowing the box.
          child: Stack(
            children: [
              // Full-width so the tile fills its row — a Stack sizes to its
              // non-positioned child, unlike the old Expanded.
              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          TagChip(label: q.subject, color: accent),
                          const Spacer(),
                          Pressable(
                            onTap: () => ref
                                .read(starredQuestionsProvider.notifier)
                                .toggle(q.id),
                            child: Icon(
                              starred
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              size: 20,
                              color: starred
                                  ? const Color(0xFFF59E0B)
                                  : p.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        q.question,
                        style: text.bodyMedium?.copyWith(
                          color: p.textPrimary,
                          height: 1.45,
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: !_open
                            ? const SizedBox(width: double.infinity)
                            : Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 16,
                                          color: Color(0xFF059669),
                                        ),
                                        const SizedBox(width: 7),
                                        Expanded(
                                          child: Text(
                                            q.options[q.correctIndex],
                                            style: text.labelLarge?.copyWith(
                                              color: const Color(0xFF059669),
                                              fontWeight: FontWeight.w700,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      q.explanation,
                                      style: text.labelMedium?.copyWith(
                                        color: p.textSecondary,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _open
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: accent,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _open ? 'Hide answer' : 'Show answer',
                            style: text.labelSmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Subject-coloured spine, full height of the tile.
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                child: Container(width: 4, color: accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A glossy, 3D subject badge — same treatment as the path's level nodes, so
/// the question screens feel of-a-piece with the Learn tab.
class SubjectBadge extends StatelessWidget {
  const SubjectBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 1.0,
          colors: [Color.lerp(color, Colors.white, 0.4)!, color],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.34),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}

/// The app's signature purple gradient hero — a glossy, lit-from-above banner
/// with soft decorative circles. Used to head the question screens so they
/// match the week card and exam-countdown banner.
class GradientHeroCard extends StatelessWidget {
  const GradientHeroCard({
    super.key,
    required this.eyebrow,
    required this.title,
    this.trailing,
    this.pills = const [],
  });

  final String eyebrow;
  final String title;
  final Widget? trailing;
  final List<Widget> pills;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: p.accent.withValues(alpha: 0.36),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6D28D9), Color(0xFFA070FF)],
                  ),
                ),
              ),
            ),
            Positioned(top: -28, right: -18, child: _circle(110, 0.12)),
            Positioned(bottom: -40, left: -26, child: _circle(120, 0.08)),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.16),
                      Colors.white.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.55],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              eyebrow,
                              style: text.labelSmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                                letterSpacing: 1.6,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              title,
                              style: text.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: 12),
                        trailing!,
                      ],
                    ],
                  ),
                  if (pills.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(spacing: 8, runSpacing: 8, children: pills),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );
}

/// A translucent stat pill for use on the gradient hero headers.
class HeroStatPill extends StatelessWidget {
  const HeroStatPill({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.9)),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: text.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
