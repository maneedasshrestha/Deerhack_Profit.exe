import 'package:flutter/material.dart';

import 'mock_data.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Weekly plan domain — the heart of the app. The onboarding inputs (exam,
// exam date, target marks, daily hours) produce a week-by-week plan; each
// week is a Duolingo-style path of MCQ levels, a bonus flashcard deck, and a
// closing mock test whose result drafts the next week.
// ═══════════════════════════════════════════════════════════════════════════

enum LevelType { mcq, flashcards, mockTest }

enum LevelStatus { locked, available, current, completed }

class WeekLevel {
  const WeekLevel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.status,
    required this.dayLabel,
    this.stars = 0,
  });

  final String id;
  final String title;
  final String subtitle;
  final LevelType type;
  final LevelStatus status;

  /// Short tag above the node — "Day 1", "Bonus", "Sunday".
  final String dayLabel;
  final int stars;

  bool get isLocked => status == LevelStatus.locked;
  bool get isCompleted => status == LevelStatus.completed;
  bool get isCurrent => status == LevelStatus.current;
}

class WeekPlan {
  const WeekPlan({
    required this.weekNumber,
    required this.totalWeeks,
    required this.theme,
    required this.targets,
    required this.levels,
  });

  final int weekNumber;
  final int totalWeeks;

  /// Human title for the week, e.g. "Energy & Derivatives".
  final String theme;

  /// The weak points this week was drafted to repair.
  final List<String> targets;
  final List<WeekLevel> levels;

  int get completedCount => levels.where((l) => l.isCompleted).length;
  double get progress => levels.isEmpty ? 0 : completedCount / levels.length;
}

class Flashcard {
  const Flashcard({
    required this.id,
    required this.statement,
    required this.isTrue,
    required this.note,
    required this.subject,
  });

  final String id;
  final String statement;
  final bool isTrue;

  /// One-line reinforcement shown after the swipe.
  final String note;
  final String subject;
}

class SubjectProgress {
  const SubjectProgress({
    required this.subject,
    required this.color,
    required this.icon,
    required this.completedTopics,
    required this.totalTopics,
  });

  final String subject;
  final Color color;
  final IconData icon;
  final int completedTopics;
  final int totalTopics;

  double get percent => totalTopics == 0 ? 0 : completedTopics / totalTopics;
}

class PlanStats {
  const PlanStats({
    required this.lastMockScore,
    required this.lastMockTotal,
    required this.lastMockLabel,
    required this.weekAccuracy,
    required this.weekQuestionsDone,
    required this.weakPoints,
    required this.focusSummary,
  });

  final int lastMockScore;
  final int lastMockTotal;
  final String lastMockLabel;
  final int weekAccuracy;
  final int weekQuestionsDone;
  final List<String> weakPoints;
  final String focusSummary;

  double get lastMockPercent =>
      lastMockTotal == 0 ? 0 : lastMockScore / lastMockTotal;
}

// ═══════════════════════════════════════════════════════════════════════════
// Static plan catalogue (MVP — generated server-side later)
// ═══════════════════════════════════════════════════════════════════════════

class PlanData {
  PlanData._();

  // ── Onboarding-derived facts ──────────────────────────────────────────────
  static const String examName = 'IOE Entrance';
  static const int daysToExam = 101;
  static const int targetMarks = 120;
  static const double dailyHours = 1.5;

  // ── This week ─────────────────────────────────────────────────────────────
  static const WeekPlan currentWeek = WeekPlan(
    weekNumber: 4,
    totalWeeks: 14,
    theme: 'Energy & Derivatives',
    targets: ['Work–energy theorem', 'Chain rule', 'Chemical bonding'],
    levels: [
      WeekLevel(
        id: 'w4_d1',
        title: 'Mixed warm-up',
        subtitle: 'All four subjects · 10 questions',
        type: LevelType.mcq,
        status: LevelStatus.completed,
        dayLabel: 'Day 1',
        stars: 3,
      ),
      WeekLevel(
        id: 'w4_d2',
        title: 'Work & energy',
        subtitle: 'Physics focus · 10 questions',
        type: LevelType.mcq,
        status: LevelStatus.completed,
        dayLabel: 'Day 2',
        stars: 2,
      ),
      WeekLevel(
        id: 'w4_d3',
        title: 'Derivatives drill',
        subtitle: 'Maths focus · 10 questions',
        type: LevelType.mcq,
        status: LevelStatus.current,
        dayLabel: 'Day 3',
      ),
      WeekLevel(
        id: 'w4_bonus',
        title: 'Formula flash',
        subtitle: 'Swipe true or false · 8 cards',
        type: LevelType.flashcards,
        status: LevelStatus.available,
        dayLabel: 'Bonus',
      ),
      WeekLevel(
        id: 'w4_d4',
        title: 'Chemical bonding',
        subtitle: 'Chemistry focus · 10 questions',
        type: LevelType.mcq,
        status: LevelStatus.locked,
        dayLabel: 'Day 4',
      ),
      WeekLevel(
        id: 'w4_d5',
        title: 'Mixed practice',
        subtitle: 'Exam-style mix · 12 questions',
        type: LevelType.mcq,
        status: LevelStatus.locked,
        dayLabel: 'Day 5',
      ),
      WeekLevel(
        id: 'w4_mock',
        title: 'Weekly mock test',
        subtitle: 'Timed · shapes next week\'s plan',
        type: LevelType.mockTest,
        status: LevelStatus.available,
        dayLabel: 'Sunday',
      ),
    ],
  );

  /// Recap of the previous, fully completed week.
  static const int lastWeekNumber = 3;
  static const String lastWeekTheme = 'Mechanics foundations';
  static const int lastWeekMockPercent = 68;

  /// Teaser for the next week (drafted after Sunday's mock).
  static const int nextWeekNumber = 5;
  static const String nextWeekHint =
      'Drafted from Sunday\'s mock result';

  // ── Flashcards (bonus level) ──────────────────────────────────────────────
  static const List<Flashcard> formulaCards = [
    Flashcard(
      id: 'fc1',
      statement: 'W = F · d · cos θ',
      isTrue: true,
      note: 'Work is the force component along the displacement.',
      subject: 'Physics',
    ),
    Flashcard(
      id: 'fc2',
      statement: 'Kinetic energy can be negative.',
      isTrue: false,
      note: 'KE = ½mv² — mass and v² are never negative.',
      subject: 'Physics',
    ),
    Flashcard(
      id: 'fc3',
      statement: 'd/dx [sin x] = cos x',
      isTrue: true,
      note: 'A standard derivative worth instant recall.',
      subject: 'Maths',
    ),
    Flashcard(
      id: 'fc4',
      statement: 'Power = Work × time',
      isTrue: false,
      note: 'Power is work per unit time: P = W / t.',
      subject: 'Physics',
    ),
    Flashcard(
      id: 'fc5',
      statement: 'Spring PE = ½ k x²',
      isTrue: true,
      note: 'Elastic potential energy grows with the square of compression.',
      subject: 'Physics',
    ),
    Flashcard(
      id: 'fc6',
      statement: 'eˣ is its own derivative.',
      isTrue: true,
      note: 'd/dx[eˣ] = eˣ — unique among exponentials.',
      subject: 'Maths',
    ),
    Flashcard(
      id: 'fc7',
      statement: 'Friction is a conservative force.',
      isTrue: false,
      note: 'Work done by friction depends on the path taken.',
      subject: 'Physics',
    ),
    Flashcard(
      id: 'fc8',
      statement: 'Ionic bonds form by sharing electron pairs.',
      isTrue: false,
      note: 'Ionic bonds transfer electrons; covalent bonds share them.',
      subject: 'Chemistry',
    ),
  ];

  // ── Mock test (timed, mixed subjects) ─────────────────────────────────────
  static const Duration mockTestDuration = Duration(minutes: 8);
  static List<MockQuestion> get mockTestQuestions => [
        ...MockData.workEnergyQuestions.take(3),
        ...MockData.derivativesQuestions.take(3),
        ...MockData.chemistryQuestions.take(1),
        ...MockData.englishQuestions.take(1),
      ];

  /// Questions for a given MCQ level — mixes subjects like the real exam.
  static List<MockQuestion> questionsForLevel(String levelId) {
    return switch (levelId) {
      'w4_d2' => MockData.workEnergyQuestions,
      'w4_d3' => MockData.derivativesQuestions,
      'w4_d4' => MockData.chemistryQuestions,
      _ => [
          ...MockData.workEnergyQuestions.take(2),
          ...MockData.derivativesQuestions.take(2),
          ...MockData.chemistryQuestions.take(2),
          ...MockData.englishQuestions.take(2),
        ],
    };
  }

  // ── Syllabus coverage (profile) ───────────────────────────────────────────
  static const List<SubjectProgress> syllabus = [
    SubjectProgress(
      subject: 'English',
      color: MockData.englishColor,
      icon: Icons.menu_book_rounded,
      completedTopics: 13,
      totalTopics: 18,
    ),
    SubjectProgress(
      subject: 'Physics',
      color: MockData.physicsColor,
      icon: Icons.bolt_rounded,
      completedTopics: 14,
      totalTopics: 24,
    ),
    SubjectProgress(
      subject: 'Chemistry',
      color: MockData.chemistryColor,
      icon: Icons.science_rounded,
      completedTopics: 9,
      totalTopics: 22,
    ),
    SubjectProgress(
      subject: 'Maths',
      color: MockData.mathColor,
      icon: Icons.functions_rounded,
      completedTopics: 16,
      totalTopics: 25,
    ),
  ];

  // ── Plan stats (profile) ──────────────────────────────────────────────────
  static const PlanStats planStats = PlanStats(
    lastMockScore: 17,
    lastMockTotal: 25,
    lastMockLabel: 'Week 3 mock · last Sunday',
    weekAccuracy: 74,
    weekQuestionsDone: 86,
    weakPoints: [
      'Work–energy theorem',
      'Chain rule speed',
      'Ionic vs covalent bonds',
    ],
    focusSummary:
        'Week 4 doubles down on energy methods and differentiation speed — '
        'the two areas that cost you the most marks in last Sunday\'s mock. '
        'Clear the daily levels, then retest on Sunday to confirm the gaps '
        'have closed.',
  );
}
