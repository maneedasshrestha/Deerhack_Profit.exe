import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../application/study_providers.dart';
import '../../domain/mock_data.dart';
import '../../domain/plan_data.dart';
import 'question_bank_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ProfileScreen — calm and scannable. Three ideas, one per section:
//   1. Syllabus — how much of each subject is covered.
//   2. The plan — last mock → this week's targets → next mock, as a timeline.
//   3. Starred questions — collapsed until asked for.
// ═══════════════════════════════════════════════════════════════════════════
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Pinned header — the back button never scrolls away.
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
                  Text('Profile',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  const SliverToBoxAdapter(
                      child: StaggeredEntrance(child: _ProfileHeader())),
                  const SliverToBoxAdapter(
                      child: StaggeredEntrance(
                          index: 1, child: _ExamCountdownBanner())),
                  const SliverToBoxAdapter(child: SectionHeader('Syllabus')),
                  const SliverToBoxAdapter(
                      child: StaggeredEntrance(
                          index: 2, child: _SyllabusCard())),
                  const SliverToBoxAdapter(child: SectionHeader('Your plan')),
                  const SliverToBoxAdapter(
                      child: StaggeredEntrance(
                          index: 3, child: _PlanTimelineCard())),
                  const SliverToBoxAdapter(child: SectionHeader('Practice')),
                  const SliverToBoxAdapter(
                      child: StaggeredEntrance(
                          index: 4, child: _QuestionBankCard())),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  const SliverToBoxAdapter(
                      child: StaggeredEntrance(
                          index: 5, child: _StarredSection())),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header: who + how long to go. Nothing else. ──────────────────────────────
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF9F5BFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                MockData.userName.split(' ').map((w) => w[0]).take(2).join(),
                style: text.headlineSmall?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(MockData.userName, style: text.headlineSmall),
                const SizedBox(height: 3),
                Text(
                  '${PlanData.examName} · target ${PlanData.targetMarks} marks',
                  style: text.labelMedium?.copyWith(color: p.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Exam countdown banner (the hero) ─────────────────────────────────────────
// The run-up to D-day, framed as a finish line: a big day count and a runway
// track that advances each prep week toward the checkered flag.
class _ExamCountdownBanner extends StatelessWidget {
  const _ExamCountdownBanner();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    const week = PlanData.currentWeek;
    final progress =
        ((week.weekNumber - 1) / week.totalWeeks).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.hairline, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2A2150).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sports_score_rounded, size: 15, color: p.accent),
              const SizedBox(width: 6),
              Text(
                PlanData.examName.toUpperCase(),
                style: text.labelSmall?.copyWith(
                  color: p.accent,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${PlanData.daysToExam}',
                style: text.displayMedium?.copyWith(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  fontSize: 52,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'days to go',
                  style: text.titleMedium?.copyWith(color: p.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _RunwayBar(progress: progress),
          const SizedBox(height: 10),
          Text(
            'Week ${week.weekNumber} of ${week.totalWeeks}',
            style: text.labelMedium?.copyWith(color: p.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// A horizontal "runway" to the exam: a track with a glowing marker at the
/// current week and a checkered flag at the finish.
class _RunwayBar extends StatelessWidget {
  const _RunwayBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final fill = (w * progress).clamp(0.0, w);
              return SizedBox(
                height: 14,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: p.surfaceHigh,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      width: fill,
                      height: 8,
                      decoration: BoxDecoration(
                        color: p.accent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Positioned(
                      left: (fill - 7).clamp(0.0, w - 14),
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: p.accent,
                          border: Border.all(color: p.surface, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: p.accent.withValues(alpha: 0.45),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Icon(Icons.sports_score_rounded, size: 22, color: p.textSecondary),
      ],
    );
  }
}

// ─── Syllabus: one slim row per subject ───────────────────────────────────────
class _SyllabusCard extends StatelessWidget {
  const _SyllabusCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AppCard(
        child: Column(
          children: [
            for (var i = 0; i < PlanData.syllabus.length; i++) ...[
              _SubjectRow(progress: PlanData.syllabus[i]),
              if (i < PlanData.syllabus.length - 1) const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.progress});
  final SubjectProgress progress;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final pct = (progress.percent * 100).round();

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: progress.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(progress.icon, size: 18, color: progress.color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(progress.subject, style: text.labelLarge),
              const SizedBox(height: 5),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress.percent),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: v,
                    minHeight: 6,
                    backgroundColor: p.surfaceHigh,
                    valueColor: AlwaysStoppedAnimation(progress.color),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 42,
          child: Text(
            '$pct%',
            textAlign: TextAlign.right,
            style: text.labelLarge?.copyWith(
              color: progress.color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Question bank entry ──────────────────────────────────────────────────────
class _QuestionBankCard extends StatelessWidget {
  const _QuestionBankCard();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final total = PlanData.questionBank
        .fold<int>(0, (sum, g) => sum + g.questions.length);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AppCard(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const QuestionBankScreen()),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: p.accentSoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.library_books_rounded,
                  size: 22, color: p.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Question bank', style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Browse all $total questions across every subject',
                    style: text.labelMedium?.copyWith(color: p.textTertiary),
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

// ─── The plan, as a three-step timeline ───────────────────────────────────────
class _PlanTimelineCard extends StatelessWidget {
  const _PlanTimelineCard();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    const stats = PlanData.planStats;
    final lastPct = (stats.lastMockPercent * 100).round();
    final delta = stats.weekAccuracy - lastPct;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TimelineStep(
              state: _StepState.done,
              title: 'Week 3 mock — $lastPct%',
              subtitle: 'Last Sunday · revealed ${stats.weakPoints.length} '
                  'weak spots',
            ),
            _TimelineStep(
              state: _StepState.current,
              title: 'This week — close the gaps',
              subtitle:
                  '${stats.weekAccuracy}% accuracy so far across '
                  '${stats.weekQuestionsDone} questions'
                  '${delta != 0 ? '  ·  ${delta > 0 ? '+' : ''}$delta% vs the mock' : ''}',
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final w in stats.weakPoints)
                      TagChip(label: w, color: p.accent),
                  ],
                ),
              ),
            ),
            const _TimelineStep(
              state: _StepState.next,
              title: 'Sunday — retest',
              subtitle:
                  'The same weak spots, under exam time. The result drafts '
                  'Week ${PlanData.nextWeekNumber}.',
              isLast: true,
            ),
            const SizedBox(height: 4),
            Text(
              stats.focusSummary,
              style: text.labelMedium
                  ?.copyWith(color: p.textTertiary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

enum _StepState { done, current, next }

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.state,
    required this.title,
    required this.subtitle,
    this.child,
    this.isLast = false,
  });

  final _StepState state;
  final String title;
  final String subtitle;
  final Widget? child;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    final (Color dotColor, Widget dotChild) = switch (state) {
      _StepState.done => (
          const Color(0xFF059669),
          const Icon(Icons.check_rounded, size: 13, color: Colors.white)
        ),
      _StepState.current => (
          p.accent,
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Colors.white),
          )
        ),
      _StepState.next => (p.surfaceHigh, const SizedBox()),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  border: state == _StepState.next
                      ? Border.all(color: p.hairline, width: 1.5)
                      : null,
                ),
                child: Center(child: dotChild),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: state == _StepState.done
                          ? const Color(0xFF059669).withValues(alpha: 0.35)
                          : p.surfaceHigh,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 12 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: state == _StepState.next
                          ? p.textTertiary
                          : p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: text.labelMedium
                        ?.copyWith(color: p.textTertiary, height: 1.4),
                  ),
                  ?child,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Starred questions: collapsed by default ──────────────────────────────────
class _StarredSection extends ConsumerStatefulWidget {
  const _StarredSection();

  @override
  ConsumerState<_StarredSection> createState() => _StarredSectionState();
}

class _StarredSectionState extends ConsumerState<_StarredSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final starred = ref.watch(starredQuestionListProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Pressable(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Color(0xFFF59E0B), size: 22),
                    const SizedBox(width: 10),
                    Text('Starred questions', style: text.titleMedium),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: p.surfaceHigh,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text('${starred.length}',
                          style: text.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    const Spacer(),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          color: p.textTertiary),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !_expanded
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      children: [
                        Divider(
                            height: 0, thickness: 0.5, color: p.hairline),
                        if (starred.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Tap the star on any question during practice '
                              'to pin it here for revision.',
                              style:
                                  text.bodyMedium?.copyWith(height: 1.4),
                            ),
                          )
                        else
                          for (var i = 0; i < starred.length; i++) ...[
                            _StarredTile(question: starred[i]),
                            if (i < starred.length - 1)
                              Divider(
                                  height: 0,
                                  thickness: 0.5,
                                  color: p.hairline),
                          ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarredTile extends ConsumerStatefulWidget {
  const _StarredTile({required this.question});
  final MockQuestion question;

  @override
  ConsumerState<_StarredTile> createState() => _StarredTileState();
}

class _StarredTileState extends ConsumerState<_StarredTile> {
  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final q = widget.question;

    return Pressable(
      onTap: () => setState(() => _showAnswer = !_showAnswer),
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TagChip(label: q.subject, color: p.accent),
                const Spacer(),
                Pressable(
                  onTap: () => ref
                      .read(starredQuestionsProvider.notifier)
                      .toggle(q.id),
                  child: Icon(Icons.close_rounded,
                      size: 17, color: p.textTertiary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              q.question,
              style: text.bodyMedium
                  ?.copyWith(color: p.textPrimary, height: 1.45),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !_showAnswer
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${q.options[q.correctIndex]} — ${q.explanation}',
                        style: text.labelMedium?.copyWith(
                          color: const Color(0xFF059669),
                          height: 1.45,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              _showAnswer ? 'tap to hide answer' : 'tap to show answer',
              style: text.labelSmall?.copyWith(color: p.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
