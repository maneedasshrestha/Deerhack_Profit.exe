import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ioe_exam.dart';
import '../domain/mock_data.dart';
import '../domain/plan_data.dart';

// ═══════════════════════════════════════════════════════════════════════════
// WeeklyMockRepository — loads the end-of-week mock paper.
//
// The real implementation pulls a full question set out of Supabase's
// `questions` table, ordered exactly as the paper is sat (by question_number),
// and turns each row into a [MockQuestion]. As more sets are uploaded, the
// week number rotates through them so consecutive weekly mocks aren't the
// same paper. When Supabase isn't configured, the offline fallback serves the
// static MVP questions so the app still runs end-to-end with no backend.
// ═══════════════════════════════════════════════════════════════════════════
abstract class WeeklyMockRepository {
  /// Loads the paper for [weekNumber]. Throws on network/permission failure so
  /// the screen can show a retry instead of a silent empty test.
  Future<WeeklyMockExam> loadExam({int weekNumber = 1});
}

/// Offline stand-in — wraps the static [PlanData] mock so the weekly mock works
/// with no backend. One synthetic set, sized like a short practice paper.
class OfflineWeeklyMockRepository implements WeeklyMockRepository {
  const OfflineWeeklyMockRepository();

  @override
  Future<WeeklyMockExam> loadExam({int weekNumber = 1}) async {
    return WeeklyMockExam(setNumber: 1, questions: PlanData.mockTestQuestions);
  }
}

class SupabaseWeeklyMockRepository implements WeeklyMockRepository {
  const SupabaseWeeklyMockRepository();

  static const String _table = 'questions';

  SupabaseClient get _sb => Supabase.instance.client;

  @override
  Future<WeeklyMockExam> loadExam({int weekNumber = 1}) async {
    final sets = await _availableSets();
    if (sets.isEmpty) {
      // No data uploaded yet — fall back rather than hand back an empty paper.
      return const OfflineWeeklyMockRepository().loadExam(weekNumber: weekNumber);
    }
    // Rotate through whatever sets exist so each week's mock is a fresh paper.
    final setNumber = sets[(weekNumber - 1) % sets.length];

    final rows = await _sb
        .from(_table)
        .select()
        .eq('set_number', setNumber)
        .order('question_number', ascending: true);

    final questions = <MockQuestion>[];
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      final q = _toQuestion(row);
      if (q != null) questions.add(q);
    }
    if (questions.isEmpty) {
      return const OfflineWeeklyMockRepository().loadExam(weekNumber: weekNumber);
    }
    return WeeklyMockExam(setNumber: setNumber, questions: questions);
  }

  /// Distinct set numbers, ascending. Each set is a complete paper.
  Future<List<int>> _availableSets() async {
    final rows = await _sb
        .from(_table)
        .select('set_number')
        .order('set_number', ascending: true);
    final seen = <int>{};
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      final n = (row['set_number'] as num?)?.toInt();
      if (n != null) seen.add(n);
    }
    return seen.toList()..sort();
  }

  /// Maps a `questions` row onto a [MockQuestion]. Returns null for rows missing
  /// the text or a usable correct answer, so a bad row drops out of the paper
  /// instead of crashing the test.
  static MockQuestion? _toQuestion(Map<String, dynamic> row) {
    final text = (row['question_text'] as String?)?.trim();
    if (text == null || text.isEmpty) return null;

    final options = <String>[
      (row['option_a'] as String?)?.trim() ?? '',
      (row['option_b'] as String?)?.trim() ?? '',
      (row['option_c'] as String?)?.trim() ?? '',
      (row['option_d'] as String?)?.trim() ?? '',
    ];

    final correctIndex = _letterToIndex(row['correct_answer'] as String?);
    if (correctIndex == null || options[correctIndex].isEmpty) return null;

    final qNum = (row['question_number'] as num?)?.toInt();
    final setNum = (row['set_number'] as num?)?.toInt() ?? 0;

    // The DB explanation is one templated blob ("✅ Correct… ❌ Wrong… 💡 Tip…").
    // Split it into the correct reason, a per-option "why it's wrong" list, and
    // the tip — so the UI can pin each reason to its own option and tuck the tip
    // behind a toggle, instead of dumping the whole emoji-laden block at once.
    final parsed = _parseExplanation(
      (row['explanation'] as String?) ?? '',
      options.length,
      correctIndex,
    );

    return MockQuestion(
      id: 'mock_s${setNum}_q${qNum ?? text.hashCode}',
      question: text,
      options: options,
      correctIndex: correctIndex,
      explanation: parsed.explanation,
      whyWrong: parsed.whyWrong,
      tip: parsed.tip,
      subject: (row['subject'] as String?)?.trim() ?? 'General',
      chapter: (row['chapter'] as String?)?.trim(),
      marks: (row['marks'] as num?)?.toInt() ?? 1,
    );
  }

  /// 'A'..'D' (any case, padded) → 0..3. Null for anything else.
  static int? _letterToIndex(String? answer) {
    final a = answer?.trim().toUpperCase();
    if (a == null || a.isEmpty) return null;
    final code = a.codeUnitAt(0) - 65; // 'A' → 0
    return (code >= 0 && code <= 3) ? code : null;
  }

  /// Breaks the templated explanation into its three parts. Falls back to the
  /// whole (emoji-stripped) text as the explanation if the template markers
  /// aren't found, so an off-format row still shows something sensible.
  static ({String explanation, List<String> whyWrong, String? tip})
      _parseExplanation(String raw, int optionCount, int correctIndex) {
    final whyWrong = List<String>.filled(optionCount, '');
    if (raw.trim().isEmpty) {
      return (explanation: '', whyWrong: whyWrong, tip: null);
    }

    // Section boundaries, located by the template's labels.
    final wrongMatch =
        RegExp(r'Wrong Answer', caseSensitive: false).firstMatch(raw);
    final tipMatch = RegExp(r'\bTip\b', caseSensitive: false).firstMatch(raw);

    final tipStart = tipMatch?.start ?? raw.length;
    var wrongStart = wrongMatch?.start ?? tipStart;
    if (wrongStart > tipStart) wrongStart = tipStart;

    var correctPart = raw.substring(0, wrongStart);
    var wrongPart =
        wrongMatch != null ? raw.substring(wrongStart, tipStart) : '';
    var tipPart = tipMatch != null ? raw.substring(tipStart) : '';

    // Strip the section labels themselves.
    correctPart = correctPart.replaceAll(
        RegExp(r'Correct Answer\s*\(?[A-D]?\)?\s*:?', caseSensitive: false), '');
    wrongPart = wrongPart.replaceAll(
        RegExp(r'Wrong Answers?\s*:?', caseSensitive: false), '');
    tipPart = tipPart.replaceAll(RegExp(r'Tip\s*:?', caseSensitive: false), '');

    // Pull each "A) reason  B) reason …" segment onto its option.
    final letterRe =
        RegExp(r'([A-D])\)\s*(.*?)(?=\s*[A-D]\)|$)', dotAll: true);
    for (final m in letterRe.allMatches(wrongPart)) {
      final idx = m.group(1)!.codeUnitAt(0) - 65;
      if (idx >= 0 && idx < optionCount && idx != correctIndex) {
        whyWrong[idx] = _clean(m.group(2) ?? '');
      }
    }

    final explanation = _clean(correctPart);
    final tipClean = _clean(tipPart);
    return (
      explanation: explanation,
      whyWrong: whyWrong,
      tip: tipClean.isEmpty ? null : tipClean,
    );
  }

  /// Removes emojis/variation selectors and collapses whitespace.
  static String _clean(String s) => s
      .replaceAll(
        RegExp(r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE00}-\u{FE0F}]',
            unicode: true),
        ' ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
