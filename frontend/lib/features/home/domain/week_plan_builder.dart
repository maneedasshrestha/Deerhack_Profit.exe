import '../../onboarding/domain/curated_plan.dart';
import '../../onboarding/domain/user_profile.dart';
import 'mock_data.dart';
import 'plan_data.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Rule-based week-map builder. The onboarding facts (days remaining, exam,
// target, daily hours) collapse into a small, fixed set of plan *tiers*, and
// each tier renders a different Duolingo-style week map. No backend / LLM — it's
// deterministic, offline, and bounded (4 tiers), which is exactly what the
// hackathon needs.
//
//   tierFor(days) → PlanTier → a week template → buildWeekPlan() → WeekPlan
//
// The home screen feeds the resulting WeekPlan straight into the existing path
// UI, so picking an exam 10 days out vs. 6 months out produces a visibly
// different map. Falls back to PlanData.currentWeek when there's no profile yet.
// ═══════════════════════════════════════════════════════════════════════════

/// The four shapes a plan can take, decided purely by days-to-exam.
enum PlanTier { sprint, short, standard, long }

/// The single rule that turns "days remaining" into one of four plans.
PlanTier tierFor(int days) {
  if (days <= 21) return PlanTier.sprint; // ≤3 wk: revision + mocks only
  if (days <= 60) return PlanTier.short; // ~3–8 wk: fast coverage → mocks
  if (days <= 120) return PlanTier.standard; // ~9–17 wk: foundations → mocks
  return PlanTier.long; // >120: deep foundations, gentler pace
}

extension PlanTierInfo on PlanTier {
  /// Short human label, shown if the UI wants to name the plan style.
  String get label => switch (this) {
        PlanTier.sprint => 'Sprint',
        PlanTier.short => 'Focused',
        PlanTier.standard => 'Balanced',
        PlanTier.long => 'Foundation',
      };
}

/// What a node in a week template *is*, before real subjects/labels fill it in.
enum _Role { warmup, subject, mixed, weakest, foundation, flashcards, mock, diagnostic }

class _NodeSpec {
  const _NodeSpec(this.type, this.role);
  final LevelType type;
  final _Role role;
}

// ── The fixed templates — one per tier (this is the "limited set"). ──────────
// The number and mix of nodes is what makes each tier's map look different.
const Map<PlanTier, List<_NodeSpec>> _templates = {
  // Test-heavy, no theory: diagnose, drill the weak spots, prove it.
  PlanTier.sprint: [
    _NodeSpec(LevelType.mockTest, _Role.diagnostic),
    _NodeSpec(LevelType.mcq, _Role.mixed),
    _NodeSpec(LevelType.mcq, _Role.weakest),
    _NodeSpec(LevelType.flashcards, _Role.flashcards),
    _NodeSpec(LevelType.mockTest, _Role.mock),
  ],
  // Brisk: a warm-up, two subjects, bonus, weekly mock.
  PlanTier.short: [
    _NodeSpec(LevelType.mcq, _Role.warmup),
    _NodeSpec(LevelType.mcq, _Role.subject),
    _NodeSpec(LevelType.mcq, _Role.subject),
    _NodeSpec(LevelType.flashcards, _Role.flashcards),
    _NodeSpec(LevelType.mockTest, _Role.mock),
  ],
  // Balanced: the full seven-node week (mirrors the original static map).
  PlanTier.standard: [
    _NodeSpec(LevelType.mcq, _Role.warmup),
    _NodeSpec(LevelType.mcq, _Role.subject),
    _NodeSpec(LevelType.mcq, _Role.subject),
    _NodeSpec(LevelType.flashcards, _Role.flashcards),
    _NodeSpec(LevelType.mcq, _Role.subject),
    _NodeSpec(LevelType.mcq, _Role.mixed),
    _NodeSpec(LevelType.mockTest, _Role.mock),
  ],
  // Slow build: foundations first, one mock to close the week.
  PlanTier.long: [
    _NodeSpec(LevelType.mcq, _Role.foundation),
    _NodeSpec(LevelType.mcq, _Role.foundation),
    _NodeSpec(LevelType.mcq, _Role.subject),
    _NodeSpec(LevelType.flashcards, _Role.flashcards),
    _NodeSpec(LevelType.mockTest, _Role.mock),
  ],
};

const List<String> _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

const List<String> _fallbackSubjects = ['Core theory', 'Problem solving', 'Revision'];

/// Builds the week map for [weekNumber] from the learner's profile and (when
/// available) the curated plan. Pure and deterministic — same inputs, same map.
WeekPlan buildWeekPlan({
  required UserProfile profile,
  CuratedPlan? plan,
  int weekNumber = 1,
}) {
  final tier = tierFor(profile.daysToExam());
  final totalWeeks =
      plan?.totalWeeks ?? (profile.daysToExam() / 7).round().clamp(1, 200);
  final subjects = (plan?.subjectFocus.map((s) => s.subject).toList() ?? const [])
      .where((s) => s.isNotEmpty)
      .toList();
  final subjectPool = subjects.isEmpty ? _fallbackSubjects : subjects;

  final specs = _templates[tier]!;
  final levels = <WeekLevel>[];
  var subjectIdx = 0;
  var weekdayIdx = 0;

  for (var i = 0; i < specs.length; i++) {
    final spec = specs[i];
    final isLast = i == specs.length - 1;

    // Day tag: flashcards are the "Bonus", the closing mock is "Sunday",
    // everything else takes the next weekday in order.
    final String dayLabel;
    if (spec.role == _Role.flashcards) {
      dayLabel = 'Bonus';
    } else if (spec.type == LevelType.mockTest && isLast) {
      dayLabel = 'Sunday';
    } else {
      dayLabel = _weekdays[weekdayIdx++ % _weekdays.length];
    }

    final subject = subjectPool[subjectIdx % subjectPool.length];
    if (spec.role == _Role.subject ||
        spec.role == _Role.foundation ||
        spec.role == _Role.weakest) {
      subjectIdx++;
    }

    // Fresh week: the first node is where you are; the bonus deck is playable;
    // everything else waits its turn.
    final LevelStatus status;
    if (i == 0) {
      status = LevelStatus.current;
    } else if (spec.role == _Role.flashcards) {
      status = LevelStatus.available;
    } else {
      status = LevelStatus.locked;
    }

    // Subject-focused roles drill one subject; warm-ups/mixes/bonus span all.
    final levelSubject = switch (spec.role) {
      _Role.subject || _Role.foundation || _Role.weakest => subject,
      _ => null,
    };

    levels.add(WeekLevel(
      id: 'w${weekNumber}_n$i',
      title: _titleFor(spec.role, subject),
      subtitle: _subtitleFor(spec.role, subject),
      type: spec.type,
      status: status,
      dayLabel: dayLabel,
      subject: levelSubject,
      questionCount: _countFor(spec.role),
    ));
  }

  return WeekPlan(
    weekNumber: weekNumber,
    totalWeeks: totalWeeks,
    theme: _themeFor(tier, plan, weekNumber, totalWeeks),
    targets: _targetsFor(plan, subjectPool),
    levels: levels,
  );
}

int _countFor(_Role role) => switch (role) {
      _Role.foundation => 8,
      _Role.flashcards => 8,
      _Role.mixed => 12,
      _Role.mock || _Role.diagnostic => 0, // sized by the loaded paper
      _ => 10,
    };

// ── Progression ──────────────────────────────────────────────────────────────
/// Re-derives each level's status from the set of completed level ids, so the
/// map advances as the learner clears nodes: completed levels show done, the
/// first unfinished required level becomes *current*, and everything past it
/// stays locked. The bonus flashcard deck is always playable and never blocks
/// the chain. [progress] maps a completed level id → the stars it earned.
WeekPlan applyProgress(WeekPlan plan, Map<String, int> progress) {
  var requiredChainOpen = true; // is the next required node unlocked yet?
  final levels = <WeekLevel>[];

  for (final level in plan.levels) {
    final done = progress.containsKey(level.id);
    final stars = progress[level.id] ?? 0;

    LevelStatus status;
    if (level.type == LevelType.flashcards) {
      // Bonus: playable from the start, doesn't gate the rest of the week.
      status = done ? LevelStatus.completed : LevelStatus.available;
    } else if (done) {
      status = LevelStatus.completed;
    } else if (requiredChainOpen) {
      status = LevelStatus.current; // the one "you are here" node
      requiredChainOpen = false; // everything after waits its turn
    } else {
      status = LevelStatus.locked;
    }

    levels.add(level.copyWith(status: status, stars: stars));
  }

  return WeekPlan(
    weekNumber: plan.weekNumber,
    totalWeeks: plan.totalWeeks,
    theme: plan.theme,
    targets: plan.targets,
    levels: levels,
  );
}

/// The questions a given MCQ [level] serves, sliced out of the full exam [pool]
/// pulled from Supabase. Subject-focused levels filter to their subject; mixed
/// levels span everything. Each level takes a different window of the pool (by
/// id) so two levels don't show the same questions. Falls back to the static
/// bank when the pool hasn't loaded (offline / still fetching).
List<MockQuestion> questionsForLevel(WeekLevel level, List<MockQuestion> pool) {
  if (pool.isEmpty) return PlanData.questionsForLevel(level.id);

  final n = level.questionCount <= 0 ? 10 : level.questionCount;
  var candidates = pool;
  final subject = level.subject;
  if (subject != null && subject.isNotEmpty) {
    final filtered = pool
        .where((q) => q.subject.toLowerCase() == subject.toLowerCase())
        .toList();
    // Only specialise if the subject actually has enough questions to fill a
    // level; otherwise fall back to the mixed pool.
    if (filtered.length >= 3) candidates = filtered;
  }

  if (candidates.length <= n) return candidates;
  // Stable per-level offset so each node gets a distinct, repeatable slice.
  final offset = level.id.hashCode.abs() % (candidates.length - n + 1);
  return candidates.sublist(offset, offset + n);
}

String _titleFor(_Role role, String subject) => switch (role) {
      _Role.warmup => 'Mixed warm-up',
      _Role.subject => subject,
      _Role.foundation => '$subject basics',
      _Role.weakest => 'Weak-spot drill',
      _Role.mixed => 'Mixed practice',
      _Role.flashcards => 'Formula flash',
      _Role.diagnostic => 'Diagnostic test',
      _Role.mock => 'Weekly mock test',
    };

String _subtitleFor(_Role role, String subject) => switch (role) {
      _Role.warmup => 'All subjects · 10 questions',
      _Role.subject => '$subject focus · 10 questions',
      _Role.foundation => '$subject fundamentals · 8 questions',
      _Role.weakest => 'Your weak spots · 10 questions',
      _Role.mixed => 'Exam-style mix · 12 questions',
      _Role.flashcards => 'Swipe true or false · 8 cards',
      _Role.diagnostic => 'Find your starting line',
      _Role.mock => 'Timed · shapes next week\'s plan',
    };

/// Theme for the week: track the curated plan's milestones across the timeline
/// when present, otherwise a sensible tier default.
String _themeFor(PlanTier tier, CuratedPlan? plan, int weekNumber, int totalWeeks) {
  final ms = plan?.milestones ?? const [];
  if (ms.isNotEmpty) {
    final idx = totalWeeks <= 1
        ? 0
        : ((weekNumber - 1) * ms.length ~/ totalWeeks).clamp(0, ms.length - 1);
    return ms[idx].theme;
  }
  return switch (tier) {
    PlanTier.sprint => 'Exam-ready sprint',
    PlanTier.short => 'Fast-track coverage',
    PlanTier.standard => 'Building momentum',
    PlanTier.long => 'Foundations',
  };
}

List<String> _targetsFor(CuratedPlan? plan, List<String> subjectPool) {
  final focus = plan?.focusAreas ?? const [];
  if (focus.isNotEmpty) return focus.take(3).toList();
  return subjectPool.take(3).toList();
}
