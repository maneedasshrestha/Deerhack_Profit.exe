/// Who said a given turn.
enum Speaker { learner, student }

/// One turn in the conversation. The transcript is the durable artifact the
/// Feynman technique pays off on, so every spoken turn becomes one of these.
///
/// * Learner turns carry the explanation [text], the [jargon] flagged inside it
///   (drives the inline wavy underlines in reflection), and the [clarity] the
///   student assigned to that explanation.
/// * Student turns carry the [reaction] and the question in [text].
class TranscriptEntry {
  const TranscriptEntry({
    required this.speaker,
    required this.text,
    required this.at,
    this.reaction = '',
    this.jargon = const [],
    this.clarity,
  });

  final Speaker speaker;
  final String text;

  /// Student-only: the short reaction spoken before the question.
  final String reaction;

  /// Learner-only: terms used without explanation, copied verbatim from [text].
  final List<String> jargon;

  /// Learner-only: clarity (0..100) the student assigned to this explanation.
  final int? clarity;

  final DateTime at;

  bool get isLearner => speaker == Speaker.learner;

  TranscriptEntry copyWith({
    List<String>? jargon,
    int? clarity,
  }) =>
      TranscriptEntry(
        speaker: speaker,
        text: text,
        reaction: reaction,
        jargon: jargon ?? this.jargon,
        clarity: clarity ?? this.clarity,
        at: at,
      );

  Map<String, dynamic> toJson() => {
        'speaker': speaker.name,
        'text': text,
        'reaction': reaction,
        'jargon': jargon,
        'clarity': clarity,
        'at': at.toIso8601String(),
      };

  factory TranscriptEntry.fromJson(Map<String, dynamic> json) => TranscriptEntry(
        speaker: Speaker.values.firstWhere(
          (s) => s.name == json['speaker'],
          orElse: () => Speaker.learner,
        ),
        text: json['text'] as String? ?? '',
        reaction: json['reaction'] as String? ?? '',
        jargon: <String>[
          for (final t in (json['jargon'] as List? ?? const []))
            if (t is String) t,
        ],
        clarity: (json['clarity'] as num?)?.toInt(),
        at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
      );
}
