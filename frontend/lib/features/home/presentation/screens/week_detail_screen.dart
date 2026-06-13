import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../domain/plan_data.dart';
import '../widgets/question_tile.dart';
import 'question_bank_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// WeekDetailScreen — everything this week covers, in one place: each subject's
// topic and the exact MCQs that drill it. Opened by tapping the week card.
// ═══════════════════════════════════════════════════════════════════════════
class WeekDetailScreen extends StatelessWidget {
  const WeekDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    const week = PlanData.currentWeek;
    const topics = PlanData.currentWeekTopics;
    final totalQuestions =
        topics.fold<int>(0, (sum, t) => sum + t.questions.length);

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
                  Text('This week', style: text.titleMedium),
                ],
              ),
            ),
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: StaggeredEntrance(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'WEEK ${week.weekNumber} OF ${week.totalWeeks}',
                              textAlign: TextAlign.center,
                              style: text.labelSmall?.copyWith(
                                color: const Color(0xFF8B73C9),
                                letterSpacing: 1.6,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              week.theme,
                              textAlign: TextAlign.center,
                              style: text.headlineSmall?.copyWith(
                                color: const Color(0xFF5B21B6),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _StatChip(
                                  label: '${topics.length} topics',
                                  icon: Icons.category_rounded,
                                ),
                                _StatChip(
                                  label: '$totalQuestions questions',
                                  icon: Icons.quiz_rounded,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Text(
                        'Tap any question to reveal the answer.',
                        style: text.bodyMedium
                            ?.copyWith(color: p.textSecondary, height: 1.45),
                      ),
                    ),
                  ),
                  for (var i = 0; i < topics.length; i++)
                    SliverToBoxAdapter(
                      child: StaggeredEntrance(
                        index: i + 1,
                        child: _TopicSection(group: topics[i]),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: StaggeredEntrance(
                      index: topics.length + 1,
                      child: _BankLink(),
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

// ─── One subject's topic + its questions ──────────────────────────────────────
class _TopicSection extends StatelessWidget {
  const _TopicSection({required this.group});
  final TopicGroup group;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SubjectBadge(icon: group.icon, color: group.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.topic, style: text.titleMedium),
                    Text(
                      '${group.subject} · ${group.questions.length} questions',
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

// ─── Link to the full bank ────────────────────────────────────────────────────
class _BankLink extends StatelessWidget {
  const _BankLink();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
      child: AppCard(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const QuestionBankScreen()),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: p.accentSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.library_books_rounded,
                  size: 20, color: p.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Full question bank', style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Browse every question across all subjects',
                    style:
                        text.labelMedium?.copyWith(color: p.textTertiary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: p.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ─── Stat chip for the week header (light surface, black label) ───────────────
class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: p.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: p.textPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: text.labelSmall?.copyWith(
              color: p.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
