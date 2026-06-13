import 'package:flutter/material.dart';

// ── Chapter status ─────────────────────────────────────────────────────────────
enum ChapterStatus { locked, available, inProgress, completed }

// ── Data models ────────────────────────────────────────────────────────────────
class Chapter {
  const Chapter({
    required this.id,
    required this.title,
    required this.status,
    this.stars = 0,
    this.masteryPercent = 0,
    this.questionCount = 10,
  });

  final String id;
  final String title;
  final ChapterStatus status;

  /// 0–3 gold stars earned.
  final int stars;

  /// 0–100 mastery percentage.
  final int masteryPercent;
  final int questionCount;

  bool get isLocked => status == ChapterStatus.locked;
  bool get isCompleted => status == ChapterStatus.completed;
  bool get isCurrent => status == ChapterStatus.inProgress;
  bool get isAvailable => status == ChapterStatus.available;
}

class Unit {
  const Unit({
    required this.id,
    required this.title,
    required this.subject,
    required this.color,
    required this.icon,
    required this.chapters,
  });

  final String id;
  final String title;
  final String subject;
  final Color color;
  final IconData icon;
  final List<Chapter> chapters;

  int get completedCount => chapters.where((c) => c.isCompleted).length;
  int get totalCount => chapters.length;
  double get progress =>
      totalCount == 0 ? 0 : completedCount / totalCount;
}

class MockQuestion {
  const MockQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.subject,
    this.chapter,
    this.marks = 1,
    this.hint,
    this.whyWrong = const [],
  });

  final String id;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String subject;

  /// Chapter/topic the question belongs to, when known (drives weak-spot
  /// analysis on the real exam paper). Null for the static MVP bank.
  final String? chapter;

  /// Mark value of the question. The IOE paper mixes 1- and 2-mark questions,
  /// so the mock is scored in marks, not question count. Defaults to 1.
  final int marks;

  /// Socratic nudge shown after the first wrong attempt — points the learner
  /// in the right direction without giving the answer away.
  final String? hint;

  /// Why each wrong option is wrong, aligned with [options]; the entry at
  /// [correctIndex] is ignored. Empty list → no per-option notes.
  final List<String> whyWrong;
}

// ── Static mock catalogue ───────────────────────────────────────────────────────
class MockData {
  MockData._();

  // Subject colours — distinct enough to colour-code the path clearly
  static const Color physicsColor = Color(0xFF3B82F6); // blue
  static const Color chemistryColor = Color(0xFF10B981); // emerald
  static const Color mathColor = Color(0xFFF59E0B); // amber
  static const Color englishColor = Color(0xFF8B5CF6); // violet

  // ── User profile ──────────────────────────────────────────────────────────────
  static const String userName = 'Aarav Sharma';
  static const int streak = 7;
  static const int xp = 1240;
  static const int level = 8;
  static const int xpForNextLevel = 1500;
  static const int daysToExam = 101;
  static const String examName = 'IOE Entrance';
  static const String league = 'Gold';
  static const int dailyXpGoal = 50;
  static const int dailyXpEarned = 30;
  static const int totalQuestionsDone = 847;
  static const int weeklyAccuracy = 73;
  static const int duelWins = 12;
  static const int duelLosses = 5;

  // ── Learning path units ───────────────────────────────────────────────────────
  static const List<Unit> units = [
    Unit(
      id: 'unit_1',
      title: 'Mechanics',
      subject: 'Physics',
      color: physicsColor,
      icon: Icons.bolt_rounded,
      chapters: [
        Chapter(
          id: 'ch_1_1',
          title: 'Kinematics',
          status: ChapterStatus.completed,
          stars: 3,
          masteryPercent: 95,
        ),
        Chapter(
          id: 'ch_1_2',
          title: "Newton's Laws",
          status: ChapterStatus.completed,
          stars: 2,
          masteryPercent: 78,
        ),
        Chapter(
          id: 'ch_1_3',
          title: 'Work & Energy',
          status: ChapterStatus.inProgress,
          masteryPercent: 42,
        ),
        Chapter(id: 'ch_1_4', title: 'Circular Motion', status: ChapterStatus.locked),
        Chapter(id: 'ch_1_5', title: 'Gravitation', status: ChapterStatus.locked),
      ],
    ),
    Unit(
      id: 'unit_2',
      title: 'Chemical Bonding',
      subject: 'Chemistry',
      color: chemistryColor,
      icon: Icons.science_rounded,
      chapters: [
        Chapter(id: 'ch_2_1', title: 'Atomic Structure', status: ChapterStatus.locked),
        Chapter(id: 'ch_2_2', title: 'Periodic Table', status: ChapterStatus.locked),
        Chapter(id: 'ch_2_3', title: 'Chemical Bonding', status: ChapterStatus.locked),
      ],
    ),
    Unit(
      id: 'unit_3',
      title: 'Calculus',
      subject: 'Mathematics',
      color: mathColor,
      icon: Icons.functions_rounded,
      chapters: [
        Chapter(
          id: 'ch_3_1',
          title: 'Limits',
          status: ChapterStatus.completed,
          stars: 2,
          masteryPercent: 80,
        ),
        Chapter(
          id: 'ch_3_2',
          title: 'Derivatives',
          status: ChapterStatus.inProgress,
          masteryPercent: 35,
        ),
        Chapter(id: 'ch_3_3', title: 'Integration', status: ChapterStatus.locked),
        Chapter(id: 'ch_3_4', title: 'Diff. Equations', status: ChapterStatus.locked),
      ],
    ),
    Unit(
      id: 'unit_4',
      title: 'Prose & Grammar',
      subject: 'English',
      color: englishColor,
      icon: Icons.menu_book_rounded,
      chapters: [
        Chapter(id: 'ch_4_1', title: 'Reading Comprehension', status: ChapterStatus.locked),
        Chapter(id: 'ch_4_2', title: 'Grammar Essentials', status: ChapterStatus.locked),
        Chapter(id: 'ch_4_3', title: 'Vocabulary Builder', status: ChapterStatus.locked),
      ],
    ),
  ];

  // ── Questions for "Work & Energy" (ch_1_3) ────────────────────────────────────
  static const List<MockQuestion> workEnergyQuestions = [
    MockQuestion(
      id: 'q1',
      subject: 'Physics',
      question:
          'A 5 kg block moves 4 m under a constant force of 20 N parallel to\n'
          'the displacement. What is the work done?',
      options: ['40 J', '80 J', '100 J', '160 J'],
      correctIndex: 1,
      hint:
          'Work is force times the distance moved along the force. The mass '
          'of the block is a distractor here — does W = F·d need it?',
      explanation:
          'W = F · d = 20 N × 4 m = 80 J (cos 0° = 1 since force is parallel).',
      whyWrong: [
        '40 J halves the product — there is no ½ in W = F·d.',
        '',
        '100 J sneaks the 5 kg mass in — mass plays no part in W = F·d.',
        '160 J doubles the product; check 20 × 4 again.',
      ],
    ),
    MockQuestion(
      id: 'q2',
      subject: 'Physics',
      question: 'The work–energy theorem states that net work done on an object equals its change in:',
      options: ['Potential energy', 'Kinetic energy', 'Total mechanical energy', 'Momentum'],
      correctIndex: 1,
      hint:
          'Think about what net force does to an object — it accelerates it. '
          'Which form of energy depends on speed?',
      explanation:
          'W_net = ΔKE. Net work done on an object equals its change in kinetic energy.',
      whyWrong: [
        'Potential energy changes relate to conservative forces only, not net work.',
        '',
        'Mechanical energy includes PE, which net work does not directly set.',
        'Impulse, not work, equals the change in momentum.',
      ],
    ),
    MockQuestion(
      id: 'q3',
      subject: 'Physics',
      question:
          'A spring with k = 200 N/m is compressed by 0.1 m.\n'
          'What is the elastic potential energy stored?',
      options: ['0.5 J', '1 J', '2 J', '20 J'],
      correctIndex: 1,
      hint:
          'The spring formula squares the compression and halves the product. '
          'Be careful with (0.1)².',
      explanation: 'PE = ½kx² = ½ × 200 × (0.1)² = 1 J.',
      whyWrong: [
        '0.5 J halves the answer twice — the ½ appears only once.',
        '',
        '2 J forgets the ½ in ½kx².',
        '20 J uses x instead of x² — the compression must be squared.',
      ],
    ),
    MockQuestion(
      id: 'q4',
      subject: 'Physics',
      question: 'Power is defined as:',
      options: ['Work × time', 'Work / time', 'Force × velocity²', 'Energy / mass'],
      correctIndex: 1,
      hint:
          'Power measures how fast work gets done. Faster means more power '
          'for the same work — should time multiply or divide?',
      explanation:
          'P = W/t. Equivalently P = F·v (force dot velocity) in instantaneous form.',
      whyWrong: [
        'Multiplying by time would make slower work more powerful — backwards.',
        '',
        'The instantaneous form is F·v, not F·v².',
        'Energy per mass is specific energy, not power.',
      ],
    ),
    MockQuestion(
      id: 'q5',
      subject: 'Physics',
      question: 'Which of the following is a conservative force?',
      options: ['Friction', 'Air resistance', 'Gravity', 'Applied push force'],
      correctIndex: 2,
      hint:
          'A conservative force does the same work between two points no '
          'matter which path you take. Which of these ignores the path?',
      explanation:
          'Gravity is conservative — work done depends only on start/end height, not on path.',
      whyWrong: [
        'Friction dissipates more energy on longer paths — path-dependent.',
        'Air resistance also depends on the path (and speed) taken.',
        '',
        'An applied push can vary arbitrarily — nothing guarantees path independence.',
      ],
    ),
  ];

  // ── Questions for "Derivatives" (ch_3_2) ─────────────────────────────────────
  static const List<MockQuestion> derivativesQuestions = [
    MockQuestion(
      id: 'dq1',
      subject: 'Mathematics',
      question: 'd/dx [x³ + 2x² − 5x + 7] = ?',
      options: ['3x² + 4x − 5', '3x² + 2x − 5', 'x² + 4x − 5', '3x² − 4x − 5'],
      correctIndex: 0,
      hint:
          'Apply the power rule to each term separately — bring the exponent '
          'down, then reduce it by one. What happens to the constant?',
      explanation:
          'Power rule: d/dx[xⁿ] = nxⁿ⁻¹. Differentiating term by term: '
          '3x² + 4x − 5. (Constant 7 vanishes.)',
      whyWrong: [
        '',
        'The 2x² term gives 4x, not 2x — multiply by the exponent.',
        'x³ differentiates to 3x², not x².',
        'The middle sign should be +4x; only the −5x term is negative.',
      ],
    ),
    MockQuestion(
      id: 'dq2',
      subject: 'Mathematics',
      question: 'The derivative of sin(x) is:',
      options: ['-cos(x)', 'cos(x)', '-sin(x)', 'sec²(x)'],
      correctIndex: 1,
      hint:
          'Picture the sine curve at x = 0: it is rising at its steepest. '
          'Which option equals 1 there?',
      explanation: 'd/dx[sin x] = cos x. This is a standard result to memorise.',
      whyWrong: [
        '−cos x is the derivative of… work backwards: whose slope is −cos x?',
        '',
        '−sin x is the derivative of cos x, not sin x.',
        'sec²x is the derivative of tan x.',
      ],
    ),
    MockQuestion(
      id: 'dq3',
      subject: 'Mathematics',
      question: 'If y = eˣ, then dy/dx is:',
      options: ['xeˣ⁻¹', 'eˣ ln x', 'eˣ', 'e'],
      correctIndex: 2,
      hint:
          'eˣ is special: its rate of growth at any point equals its value '
          'at that point.',
      explanation: 'The exponential function eˣ is its own derivative: d/dx[eˣ] = eˣ.',
      whyWrong: [
        'The power rule applies to xⁿ, not to nˣ — the variable is in the exponent.',
        'No ln x appears when differentiating eˣ (it does for aˣ, as ln a).',
        '',
        'A constant cannot be the slope of a growing curve.',
      ],
    ),
    MockQuestion(
      id: 'dq4',
      subject: 'Mathematics',
      question: 'Using the chain rule, d/dx[sin(3x)] = ?',
      options: ['cos(3x)', '3 cos(3x)', '-cos(3x)', '-3 cos(3x)'],
      correctIndex: 1,
      hint:
          'Differentiate the outside, keep the inside, then multiply by the '
          'derivative of the inside. What is d/dx[3x]?',
      explanation: 'Chain rule: d/dx[sin(u)] = cos(u)·(du/dx). Here u = 3x, du/dx = 3.',
      whyWrong: [
        'cos(3x) forgets to multiply by the inner derivative, 3.',
        '',
        'No negative appears — sin differentiates to +cos.',
        'Both the sign and… check: sin → +cos, and the factor 3 is positive.',
      ],
    ),
    MockQuestion(
      id: 'dq5',
      subject: 'Mathematics',
      question: 'At a local maximum, the first derivative f\'(x) is:',
      options: ['Positive', 'Negative', 'Zero', 'Undefined'],
      correctIndex: 2,
      hint:
          'Imagine standing exactly on top of a hill. Which way does the '
          'ground slope under your feet?',
      explanation:
          'At a local maximum, f\'(x) = 0 (the tangent is horizontal). The sign changes from + to − around it.',
      whyWrong: [
        'A positive slope means the curve is still climbing — not the top yet.',
        'A negative slope means you are already past the peak.',
        '',
        'For smooth curves the derivative exists at the peak — it is simply zero.',
      ],
    ),
  ];

  // ── Questions for "Chemical Bonding" ─────────────────────────────────────────
  static const List<MockQuestion> chemistryQuestions = [
    MockQuestion(
      id: 'cq1',
      subject: 'Chemistry',
      question: 'Which type of bond forms when electrons are transferred from one atom to another?',
      options: ['Covalent bond', 'Ionic bond', 'Metallic bond', 'Hydrogen bond'],
      correctIndex: 1,
      hint:
          'Transfer creates charged ions — one atom loses, the other gains. '
          'Which bond is held together by opposite charges?',
      explanation:
          'Ionic bonds form by electron transfer, creating oppositely charged ions that attract.',
      whyWrong: [
        'Covalent bonds share electron pairs rather than transferring them.',
        '',
        'Metallic bonding delocalises electrons across a lattice of atoms.',
        'Hydrogen bonds are weak intermolecular attractions, not electron transfer.',
      ],
    ),
    MockQuestion(
      id: 'cq2',
      subject: 'Chemistry',
      question: 'The shape of a methane (CH₄) molecule is:',
      options: ['Linear', 'Trigonal planar', 'Tetrahedral', 'Bent'],
      correctIndex: 2,
      hint:
          'Carbon has four bonding pairs and no lone pairs. How do four '
          'pairs arrange themselves to stay as far apart as possible?',
      explanation:
          'Four bonding pairs repel equally into a tetrahedron — bond angle 109.5°.',
      whyWrong: [
        'Linear fits two electron pairs (e.g. CO₂), not four.',
        'Trigonal planar fits three pairs (e.g. BF₃).',
        '',
        'Bent shapes need lone pairs on the central atom (e.g. H₂O).',
      ],
    ),
    MockQuestion(
      id: 'cq3',
      subject: 'Chemistry',
      question: 'Which element has the highest electronegativity?',
      options: ['Oxygen', 'Chlorine', 'Fluorine', 'Nitrogen'],
      correctIndex: 2,
      hint:
          'Electronegativity rises toward the top-right of the periodic '
          'table. Which of these sits closest to that corner?',
      explanation:
          'Fluorine (3.98 on the Pauling scale) is the most electronegative element.',
      whyWrong: [
        'Oxygen is second — strong, but not the strongest.',
        'Chlorine sits one period lower than fluorine, weakening its pull.',
        '',
        'Nitrogen trails both oxygen and fluorine in its own period.',
      ],
    ),
  ];

  // ── Questions for "English" ──────────────────────────────────────────────────
  static const List<MockQuestion> englishQuestions = [
    MockQuestion(
      id: 'eq1',
      subject: 'English',
      question: 'Choose the correct sentence:',
      options: [
        'Neither of the answers were correct.',
        'Neither of the answers was correct.',
        'Neither of the answers are correct.',
        'Neither of the answer was correct.',
      ],
      correctIndex: 1,
      hint:
          '"Neither" refers to one thing at a time — is the subject singular '
          'or plural?',
      explanation:
          '"Neither" is singular, so it takes the singular verb "was". The plural "answers" belongs to the of-phrase, not the subject.',
      whyWrong: [
        '"Were" is plural, but "neither" is a singular subject.',
        '',
        '"Are" is plural and present tense — doubly wrong here.',
        '"Of the answer" needs the plural "answers" after "neither of".',
      ],
    ),
    MockQuestion(
      id: 'eq2',
      subject: 'English',
      question: 'The word "ubiquitous" most nearly means:',
      options: ['Rare', 'Everywhere', 'Ancient', 'Transparent'],
      correctIndex: 1,
      hint:
          'Think of how people describe smartphones today — found in every '
          'pocket, every room, every country.',
      explanation:
          '"Ubiquitous" means present or found everywhere at once.',
      whyWrong: [
        '"Rare" is close to the opposite of ubiquitous.',
        '',
        '"Ancient" relates to age, not spread.',
        '"Transparent" describes clarity, not presence.',
      ],
    ),
  ];

  // ── Questions lookup by chapter id ───────────────────────────────────────────
  static List<MockQuestion> questionsFor(String chapterId) {
    return switch (chapterId) {
      'ch_3_2' => derivativesQuestions,
      _ => workEnergyQuestions,
    };
  }

  /// Every question in the bank, for starred-question lookups.
  static List<MockQuestion> get allQuestions => [
        ...workEnergyQuestions,
        ...derivativesQuestions,
        ...chemistryQuestions,
        ...englishQuestions,
      ];

  // ── Friends (for duel) ────────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> friends = [
    {'name': 'Priya Shah', 'league': 'Gold', 'streak': 21, 'rating': 1510, 'initials': 'PS', 'online': true},
    {'name': 'Sita Rana', 'league': 'Gold', 'streak': 12, 'rating': 1480, 'initials': 'SR', 'online': true},
    {'name': 'Bikash KC', 'league': 'Silver', 'streak': 5, 'rating': 1220, 'initials': 'BK', 'online': false},
    {'name': 'Rohan Thapa', 'league': 'Bronze', 'streak': 3, 'rating': 1090, 'initials': 'RT', 'online': false},
  ];

  // ── Duel history ──────────────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> duelHistory = [
    {'opponent': 'Priya Shah', 'result': 'win', 'score': '4-3', 'topic': 'Kinematics', 'ago': '2h ago'},
    {'opponent': 'Sita Rana', 'result': 'loss', 'score': '2-4', 'topic': "Newton's Laws", 'ago': '1d ago'},
    {'opponent': 'Bikash KC', 'result': 'win', 'score': '5-2', 'topic': 'Limits', 'ago': '2d ago'},
  ];

  // ── Leaderboard ───────────────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> leaderboard = [
    {'name': 'Priya Shah', 'xp': 2840, 'league': 'Platinum', 'rank': 1, 'initials': 'PS'},
    {'name': 'Sita Rana', 'xp': 2420, 'league': 'Gold', 'rank': 2, 'initials': 'SR'},
    {'name': 'Dev Acharya', 'xp': 2110, 'league': 'Gold', 'rank': 3, 'initials': 'DA'},
    {'name': 'Aarav Sharma', 'xp': 1240, 'league': 'Gold', 'rank': 8, 'initials': 'AS', 'isYou': true},
    {'name': 'Bikash KC', 'xp': 980, 'league': 'Silver', 'rank': 12, 'initials': 'BK'},
  ];

  // ── League colours ─────────────────────────────────────────────────────────
  static Color leagueColor(String league) => switch (league) {
        'Platinum' => const Color(0xFF94A3B8),
        'Gold' => const Color(0xFFF59E0B),
        'Silver' => const Color(0xFF9CA3AF),
        'Bronze' => const Color(0xFFB45309),
        _ => const Color(0xFF6B7280),
      };

  static IconData leagueIcon(String league) => switch (league) {
        'Platinum' => Icons.diamond_rounded,
        'Gold' => Icons.emoji_events_rounded,
        'Silver' => Icons.military_tech_rounded,
        'Bronze' => Icons.workspace_premium_rounded,
        _ => Icons.star_rounded,
      };
}
