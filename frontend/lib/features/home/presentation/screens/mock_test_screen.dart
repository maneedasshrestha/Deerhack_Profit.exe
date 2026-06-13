import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../application/weekly_mock_providers.dart';
import '../../domain/ioe_exam.dart';
import '../../domain/mock_data.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MockTestScreen — the end-of-week quiz, sat as an exact replica of the IOE
// entrance exam. A full question set is pulled from Supabase and run under the
// real paper's rules: one global timer scaled to the IOE per-mark pace (a full
// 140-mark paper = 2 hours), no per-question feedback, no negative marking,
// scored in marks. The result drafts what next week's plan reinforces.
//
// This widget only handles loading the paper; [_MockTestRunner] runs it.
// ═══════════════════════════════════════════════════════════════════════════
class MockTestScreen extends ConsumerWidget {
  const MockTestScreen({super.key, this.weekNumber = 1, this.onCompleted});

  /// Which week's paper to sit — rotates the Supabase set so consecutive weekly
  /// mocks aren't the same exam.
  final int weekNumber;

  /// Called once the mock is submitted and dismissed — marks the Sunday node
  /// done on the week map.
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exam = ref.watch(weeklyMockExamProvider(weekNumber));
    return exam.when(
      data: (exam) => _MockTestRunner(exam: exam, onCompleted: onCompleted),
      loading: () => const _LoadingView(),
      error: (_, _) => _ErrorView(
        onRetry: () => ref.invalidate(weeklyMockExamProvider(weekNumber)),
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}

class _MockTestRunner extends StatefulWidget {
  const _MockTestRunner({required this.exam, this.onCompleted});

  final WeeklyMockExam exam;
  final VoidCallback? onCompleted;

  @override
  State<_MockTestRunner> createState() => _MockTestRunnerState();
}

enum _Stage { intro, running, results }

class _MockTestRunnerState extends State<_MockTestRunner> {
  List<MockQuestion> get _questions => widget.exam.questions;
  _Stage _stage = _Stage.intro;

  int _qIndex = 0;
  int? _selected;
  late List<int?> _answers;
  late List<int> _secondsPerQuestion;

  Timer? _ticker;
  late int _remaining; // seconds
  final Stopwatch _questionWatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _answers = List.filled(_questions.length, null);
    _secondsPerQuestion = List.filled(_questions.length, 0);
    _remaining = widget.exam.duration.inSeconds;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() => _stage = _Stage.running);
    _questionWatch.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 1) {
        _finish();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _recordCurrentTiming() {
    _secondsPerQuestion[_qIndex] += _questionWatch.elapsed.inSeconds;
    _questionWatch
      ..reset()
      ..start();
  }

  void _next() {
    _answers[_qIndex] = _selected;
    _recordCurrentTiming();
    if (_qIndex >= _questions.length - 1) {
      _finish();
      return;
    }
    setState(() {
      _qIndex++;
      _selected = _answers[_qIndex];
    });
  }

  void _prev() {
    if (_qIndex == 0) return;
    _answers[_qIndex] = _selected;
    _recordCurrentTiming();
    setState(() {
      _qIndex--;
      _selected = _answers[_qIndex];
    });
  }

  void _finish() {
    _ticker?.cancel();
    _questionWatch.stop();
    _answers[_qIndex] = _selected;
    HapticFeedback.mediumImpact();
    setState(() => _stage = _Stage.results);
  }

  int get _score => widget.exam.scoreFor(_answers);

  /// Subjects ranked by number of wrong/blank answers — the weak points that
  /// seed next week's plan.
  List<String> get _weakSubjects {
    final wrong = <String, int>{};
    for (var i = 0; i < _questions.length; i++) {
      if (_answers[i] != _questions[i].correctIndex) {
        wrong.update(_questions[i].subject, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    final entries = wrong.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in entries) e.key];
  }

  @override
  Widget build(BuildContext context) {
    return switch (_stage) {
      _Stage.intro => _IntroView(
          exam: widget.exam,
          onStart: _start,
          onClose: () => Navigator.of(context).pop(),
        ),
      _Stage.running => _buildTest(context),
      _Stage.results => _ResultsView(
          questions: _questions,
          answers: _answers,
          secondsPerQuestion: _secondsPerQuestion,
          score: _score,
          totalMarks: widget.exam.totalMarks,
          weakSubjects: _weakSubjects,
          onFinish: () {
            widget.onCompleted?.call();
            Navigator.of(context).pop();
          },
        ),
    };
  }

  Widget _buildTest(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final q = _questions[_qIndex];
    final low = _remaining <= 60;
    final hh = (_remaining ~/ 3600);
    final mm = ((_remaining % 3600) ~/ 60).toString().padLeft(2, '0');
    final ss = (_remaining % 60).toString().padLeft(2, '0');
    final clock = hh > 0 ? '$hh:$mm:$ss' : '$mm:$ss';
    final isLast = _qIndex >= _questions.length - 1;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: Row(
                children: [
                  Text(
                    'Question ${_qIndex + 1} of ${_questions.length}',
                    style:
                        text.labelMedium?.copyWith(color: p.textTertiary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '· ${q.marks} ${q.marks == 1 ? 'mark' : 'marks'}',
                    style: text.labelMedium?.copyWith(color: p.textTertiary),
                  ),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: low
                          ? const Color(0xFFE11D48).withValues(alpha: 0.1)
                          : p.surfaceHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 15,
                            color: low
                                ? const Color(0xFFE11D48)
                                : p.textSecondary),
                        const SizedBox(width: 5),
                        Text(
                          clock,
                          style: text.labelLarge?.copyWith(
                            color: low
                                ? const Color(0xFFE11D48)
                                : p.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Single progress bar — a per-question dot row doesn't fit a
            // full ~100-question paper.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (_qIndex + 1) / _questions.length,
                  minHeight: 5,
                  backgroundColor: p.surfaceHigh,
                  valueColor: AlwaysStoppedAnimation(p.accent),
                ),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0.1, 0), end: Offset.zero)
                        .animate(anim),
                    child: child,
                  ),
                ),
                child: SingleChildScrollView(
                  key: ValueKey(_qIndex),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TagChip(label: q.subject, color: p.accent),
                            const SizedBox(height: 12),
                            Text(q.question,
                                style:
                                    text.bodyLarge?.copyWith(height: 1.5)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (var i = 0; i < q.options.length; i++)
                        if (q.options[i].isNotEmpty) ...[
                          Pressable(
                            onTap: () => setState(() => _selected = i),
                            scale: 0.98,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 13),
                              decoration: BoxDecoration(
                                color:
                                    _selected == i ? p.accentSoft : p.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      _selected == i ? p.accent : p.hairline,
                                  width: _selected == i ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    String.fromCharCode(65 + i),
                                    style: text.labelLarge?.copyWith(
                                      color: _selected == i
                                          ? p.accent
                                          : p.textTertiary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      q.options[i],
                                      style: text.bodyMedium?.copyWith(
                                        color: _selected == i
                                            ? p.accent
                                            : p.textPrimary,
                                        fontWeight: _selected == i
                                            ? FontWeight.w600
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  if (_qIndex > 0) ...[
                    _NavButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: _prev,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    // Skipping is allowed — no negative marking — so this is
                    // always enabled, even with nothing selected.
                    child: AppButton(
                      label: isLast
                          ? 'Submit test'
                          : (_selected == null ? 'Skip' : 'Next question'),
                      onTap: _next,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: p.surfaceHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.hairline),
        ),
        child: Icon(icon, color: p.textSecondary),
      ),
    );
  }
}

// ─── Loading / error ───────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: p.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: p.accent),
            const SizedBox(height: 18),
            Text('Loading your exam paper…',
                style: text.bodyMedium?.copyWith(color: p.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry, required this.onClose});
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: onClose,
                  icon: Icon(Icons.close_rounded, color: p.textSecondary),
                ),
              ),
              const Spacer(),
              Icon(Icons.cloud_off_rounded, size: 48, color: p.textTertiary),
              const SizedBox(height: 16),
              Text("Couldn't load the paper",
                  style: text.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Check your connection and try again.',
                style: text.bodyMedium?.copyWith(color: p.textSecondary),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              AppButton(
                  label: 'Try again',
                  icon: Icons.refresh_rounded,
                  onTap: onRetry),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Intro ────────────────────────────────────────────────────────────────────
class _IntroView extends StatelessWidget {
  const _IntroView({
    required this.exam,
    required this.onStart,
    required this.onClose,
  });

  final WeeklyMockExam exam;
  final VoidCallback onStart;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final minutes = exam.duration.inMinutes;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: onClose,
                  icon: Icon(Icons.close_rounded, color: p.textSecondary),
                ),
              ),
              const Spacer(),
              StaggeredEntrance(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                  ),
                  child: const Icon(Icons.emoji_events_rounded,
                      color: Color(0xFFF59E0B), size: 42),
                ),
              ),
              const SizedBox(height: 20),
              StaggeredEntrance(
                index: 1,
                child: Text('Weekly mock test', style: text.displayMedium),
              ),
              const SizedBox(height: 10),
              StaggeredEntrance(
                index: 2,
                child: Text(
                  'A full IOE entrance paper under real exam conditions — same '
                  'time pressure, same rules. This is the reflection of your '
                  'week: did the weak points you trained actually close?',
                  style: text.bodyMedium?.copyWith(height: 1.5),
                ),
              ),
              const SizedBox(height: 24),
              StaggeredEntrance(
                index: 3,
                child: AppCard(
                  child: Column(
                    children: [
                      _Rule(
                        icon: Icons.timer_outlined,
                        label: '$minutes minutes · ${exam.questionCount} '
                            'questions · ${exam.totalMarks} marks',
                      ),
                      const SizedBox(height: 12),
                      const _Rule(
                        icon: Icons.remove_circle_outline_rounded,
                        label: 'No negative marking — never leave a blank',
                      ),
                      const SizedBox(height: 12),
                      const _Rule(
                        icon: Icons.visibility_off_outlined,
                        label: 'No answers shown until you submit',
                      ),
                      const SizedBox(height: 12),
                      const _Rule(
                        icon: Icons.insights_rounded,
                        label: 'Your result drafts next week\'s plan',
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              AppButton(
                label: 'Start the test',
                icon: Icons.play_arrow_rounded,
                color: const Color(0xFFF59E0B),
                onTap: onStart,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: p.accent),
        const SizedBox(width: 12),
        Expanded(
          child:
              Text(label, style: text.bodyMedium?.copyWith(height: 1.3)),
        ),
      ],
    );
  }
}

// ─── Results ──────────────────────────────────────────────────────────────────
class _ResultsView extends StatelessWidget {
  const _ResultsView({
    required this.questions,
    required this.answers,
    required this.secondsPerQuestion,
    required this.score,
    required this.totalMarks,
    required this.weakSubjects,
    required this.onFinish,
  });

  final List<MockQuestion> questions;
  final List<int?> answers;
  final List<int> secondsPerQuestion;

  /// Marks scored, out of [totalMarks].
  final int score;
  final int totalMarks;
  final List<String> weakSubjects;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final pct = totalMarks == 0 ? 0 : (score * 100) ~/ totalMarks;
    final maxSeconds = secondsPerQuestion
        .fold<int>(1, (m, s) => s > m ? s : m);
    final avgSeconds = secondsPerQuestion.isEmpty
        ? 0
        : secondsPerQuestion.reduce((a, b) => a + b) ~/
            secondsPerQuestion.length;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                      child: Column(
                        children: [
                          StaggeredEntrance(
                            child: ProgressRing(
                              progress: pct / 100,
                              size: 124,
                              strokeWidth: 10,
                              color: pct >= 70
                                  ? const Color(0xFF059669)
                                  : pct >= 40
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFFE11D48),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('$pct%',
                                      style: text.displayMedium
                                          ?.copyWith(fontSize: 32)),
                                  Text('$score/$totalMarks',
                                      style: text.labelSmall),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text('Test submitted', style: text.headlineSmall),
                          const SizedBox(height: 4),
                          Text(
                            '$score of $totalMarks marks · '
                            'avg ${avgSeconds}s per question',
                            style: text.labelMedium
                                ?.copyWith(color: p.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                      child: SectionHeader('Where your time went')),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: AppCard(
                        child: Column(
                          children: [
                            for (var i = 0; i < questions.length; i++) ...[
                              _TimeRow(
                                index: i,
                                seconds: secondsPerQuestion[i],
                                maxSeconds: maxSeconds,
                                correct: answers[i] ==
                                    questions[i].correctIndex,
                                subject: questions[i].subject,
                              ),
                              if (i < questions.length - 1)
                                const SizedBox(height: 10),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                      child: SectionHeader('What next week fixes')),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (weakSubjects.isEmpty)
                              Text(
                                'Clean sweep — next week raises the '
                                'difficulty instead of repairing gaps.',
                                style: text.bodyMedium?.copyWith(height: 1.5),
                              )
                            else ...[
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final s in weakSubjects)
                                    TagChip(
                                      label: s,
                                      icon: Icons.trending_up_rounded,
                                      color: const Color(0xFFE11D48),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Next week will weight its daily levels toward '
                                'these subjects and re-test them next Sunday.',
                                style: text.bodyMedium?.copyWith(height: 1.5),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: AppButton(label: 'Done', onTap: onFinish),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.index,
    required this.seconds,
    required this.maxSeconds,
    required this.correct,
    required this.subject,
  });

  final int index;
  final int seconds;
  final int maxSeconds;
  final bool correct;
  final String subject;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final frac = (seconds / maxSeconds).clamp(0.05, 1.0);
    final slow = seconds == maxSeconds && seconds > 0;
    final barColor = correct ? const Color(0xFF059669) : const Color(0xFFE11D48);

    return Row(
      children: [
        SizedBox(
          width: 30,
          child: Text('Q${index + 1}',
              style: text.labelMedium?.copyWith(color: p.textTertiary)),
        ),
        Icon(
          correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
          size: 16,
          color: barColor,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: frac.toDouble()),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: p.surfaceHigh,
                valueColor:
                    AlwaysStoppedAnimation(barColor.withValues(alpha: 0.7)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 44,
          child: Text(
            '${seconds}s${slow ? ' ⚠' : ''}',
            textAlign: TextAlign.right,
            style: text.labelSmall?.copyWith(
              color: slow ? const Color(0xFFB45309) : p.textTertiary,
              fontWeight: slow ? FontWeight.w700 : null,
            ),
          ),
        ),
      ],
    );
  }
}
