import 'mock_data.dart';

// ═══════════════════════════════════════════════════════════════════════════
// IOE entrance exam format — the real-paper rules the weekly mock replicates.
//
// The Tribhuvan University IOE BE/BArch entrance is a 2-hour, 140-mark
// multiple-choice paper of ~100 questions (a mix of 1- and 2-mark items),
// with NO negative marking. The end-of-week mock pulls a full question set
// from Supabase and runs it under exactly that time pressure, so a slow set
// feels as tight as the real thing.
//
// Timing is derived per-mark, not fixed: a set worth M marks gets
// M / 140 × 120 minutes. A complete 140-mark set lands on the full 2 hours;
// a partial set scales down to the identical seconds-per-mark crunch.
// ═══════════════════════════════════════════════════════════════════════════
class IoeExam {
  const IoeExam._();

  /// Full-paper totals — the reference the per-mark pace is calibrated against.
  static const int fullMarks = 140;
  static const Duration fullDuration = Duration(minutes: 120);

  /// IOE awards no marks for wrong/blank answers and deducts none either.
  static const bool negativeMarking = false;

  /// The time budget for a paper worth [totalMarks], at the real exam's pace.
  /// Clamped to a sane floor so a tiny set still gets a usable timer.
  static Duration durationForMarks(int totalMarks) {
    final seconds =
        (totalMarks / fullMarks * fullDuration.inSeconds).round();
    return Duration(seconds: seconds.clamp(60, fullDuration.inSeconds));
  }
}

/// A fully-loaded weekly mock: the ordered question paper plus the totals and
/// timer the screen runs it under. Built by the repository from a Supabase set
/// (or the offline fallback), so the UI stays free of data-loading concerns.
class WeeklyMockExam {
  WeeklyMockExam({
    required this.setNumber,
    required this.questions,
  })  : totalMarks = questions.fold(0, (sum, q) => sum + q.marks),
        duration = IoeExam.durationForMarks(
          questions.fold(0, (sum, q) => sum + q.marks),
        );

  /// Which question set this paper was drawn from.
  final int setNumber;

  /// The paper, in question-number order — mixed subjects, like the real exam.
  final List<MockQuestion> questions;

  /// Sum of every question's marks (the exam is scored out of this).
  final int totalMarks;

  /// Time allowed, scaled to the IOE per-mark pace.
  final Duration duration;

  int get questionCount => questions.length;

  /// Marks earned for [answers] (one selected option index per question, null
  /// = unanswered). No negative marking, matching the real paper.
  int scoreFor(List<int?> answers) {
    var marks = 0;
    for (var i = 0; i < questions.length; i++) {
      if (answers[i] == questions[i].correctIndex) marks += questions[i].marks;
    }
    return marks;
  }
}
