import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../domain/plan_data.dart';
import '../widgets/question_tile.dart';

// ═══════════════════════════════════════════════════════════════════════════
// QuestionBankScreen — the whole question bank, browsable and filterable by
// subject. Every question is a tap-to-reveal tile, starrable for revision.
// ═══════════════════════════════════════════════════════════════════════════
class QuestionBankScreen extends StatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  // null = "All subjects".
  String? _subject;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    const bank = PlanData.questionBank;
    final visible = _subject == null
        ? bank
        : [for (final g in bank) if (g.subject == _subject) g];
    final grandTotal =
        bank.fold<int>(0, (sum, g) => sum + g.questions.length);

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Pinned header.
            Container(
              padding: const EdgeInsets.fromLTRB(6, 4, 20, 4),
              decoration: BoxDecoration(
                color: p.bg,
                border:
                    Border(bottom: BorderSide(color: p.hairline, width: 1)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_rounded,
                        color: p.textSecondary),
                    tooltip: 'Back',
                  ),
                  Text('Question bank', style: text.titleMedium),
                ],
              ),
            ),
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: StaggeredEntrance(
                      child: GradientHeroCard(
                        eyebrow: 'QUESTION BANK',
                        title: 'Every question, one place',
                        trailing: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                          child: const Icon(Icons.library_books_rounded,
                              color: Colors.white, size: 24),
                        ),
                        pills: [
                          HeroStatPill(
                              label: '$grandTotal questions',
                              icon: Icons.quiz_rounded),
                          HeroStatPill(
                              label: '${bank.length} subjects',
                              icon: Icons.category_rounded),
                        ],
                      ),
                    ),
                  ),
                  // Subject filter chips.
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 60,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                        children: [
                          _FilterChip(
                            label: 'All',
                            icon: Icons.apps_rounded,
                            selected: _subject == null,
                            color: p.accent,
                            onTap: () => setState(() => _subject = null),
                          ),
                          for (final g in bank)
                            _FilterChip(
                              label: g.subject,
                              icon: g.icon,
                              selected: _subject == g.subject,
                              color: g.color,
                              onTap: () => setState(() => _subject = g.subject),
                            ),
                        ],
                      ),
                    ),
                  ),
                  for (var i = 0; i < visible.length; i++)
                    SliverToBoxAdapter(
                      child: StaggeredEntrance(
                        // Re-key per filter so sections re-animate on change.
                        key: ValueKey('${_subject ?? 'all'}_${visible[i].subject}'),
                        index: i,
                        child: _BankSection(group: visible[i]),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter chip ──────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Pressable(
        onTap: onTap,
        scale: 0.96,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.14) : p.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.5) : p.hairline,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 15,
                    color: selected ? color : p.textTertiary),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: text.labelMedium?.copyWith(
                  color: selected ? color : p.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── One subject section ──────────────────────────────────────────────────────
class _BankSection extends StatelessWidget {
  const _BankSection({required this.group});
  final TopicGroup group;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SubjectBadge(icon: group.icon, color: group.color, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${group.subject} · ${group.topic}',
                        style: text.titleMedium),
                    Text(
                      '${group.questions.length} questions',
                      style:
                          text.labelMedium?.copyWith(color: p.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < group.questions.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            QuestionTile(question: group.questions[i], accent: group.color),
          ],
        ],
      ),
    );
  }
}
