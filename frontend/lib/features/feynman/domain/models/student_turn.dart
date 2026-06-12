import 'dart:math' as math;

/// The AI student's reply to one explanation. This is the parsed, validated
/// shape of the backend's JSON response — the engine layer guarantees these
/// invariants so the rest of the app can trust them:
///   * [clarity] is always 0..100
///   * [jargon] never contains blank strings
class StudentTurn {
  const StudentTurn({
    required this.reaction,
    required this.question,
    required this.clarity,
    required this.jargon,
  });

  final String reaction;
  final String question;
  final int clarity;
  final List<String> jargon;

  /// Defensive parse: clamps clarity, tolerates missing/wrong-typed fields, and
  /// supplies a graceful fallback question. Used by the turn-based engine on the
  /// proxy response and reused anywhere we parse this shape.
  factory StudentTurn.fromJson(Map<String, dynamic> json) {
    final rawClarity = json['clarity'];
    final clarity = switch (rawClarity) {
      final int v => v,
      final double v => v.round(),
      final String v => int.tryParse(v.trim()) ?? 50,
      _ => 50,
    };

    final rawJargon = json['jargon'];
    final jargon = <String>[
      if (rawJargon is List)
        for (final t in rawJargon)
          if (t is String && t.trim().isNotEmpty) t.trim(),
    ];

    final question = (json['question'] as String?)?.trim();

    return StudentTurn(
      reaction: (json['reaction'] as String?)?.trim() ?? '',
      question: (question == null || question.isEmpty)
          ? 'Hmm, can you explain that part a little more simply?'
          : question,
      clarity: clarity.clamp(0, 100),
      jargon: jargon,
    );
  }

  /// The line the student speaks aloud — reaction then question.
  String get spoken => [reaction, question].where((s) => s.trim().isNotEmpty).join(' ');

  /// A neutral fallback used when the network/model fails, so the loop can
  /// continue rather than dead-end.
  static StudentTurn fallback() => StudentTurn(
        reaction: "Hmm, I didn't quite follow all of that.",
        question: 'Could you say that again in a simpler way?',
        clarity: math.max(0, 40),
        jargon: const [],
      );
}
