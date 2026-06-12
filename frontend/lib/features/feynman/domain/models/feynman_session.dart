import 'transcript_entry.dart';

/// A single recorded attempt at teaching one concept.
///
/// Versioning: every attempt at the same concept shares a [conceptId] and gets
/// an incrementing [version] (v1 → v2 → v3). "Teach it again" creates a new
/// session with the same [conceptId] and the next version, so the learner can
/// watch their explanation get clearer over time.
class FeynmanSession {
  const FeynmanSession({
    required this.id,
    required this.conceptId,
    required this.conceptName,
    required this.version,
    required this.startedAt,
    required this.transcript,
    required this.claritySeries,
    required this.gaps,
    this.endedAt,
  });

  final String id;

  /// Stable id shared by every version of the same concept.
  final String conceptId;
  final String conceptName;

  /// 1-based attempt number for this concept.
  final int version;

  final DateTime startedAt;
  final DateTime? endedAt;

  final List<TranscriptEntry> transcript;

  /// Clarity per learner turn, in order — drives the trend sparkline.
  final List<int> claritySeries;

  /// Unique jargon terms flagged across the whole session.
  final List<String> gaps;

  /// Final clarity = the most recent score, or 0 if none yet.
  int get finalClarity => claritySeries.isNotEmpty ? claritySeries.last : 0;

  int get learnerTurnCount => transcript.where((e) => e.isLearner).length;

  Duration get duration => (endedAt ?? DateTime.now()).difference(startedAt);

  FeynmanSession copyWith({
    DateTime? endedAt,
    List<TranscriptEntry>? transcript,
    List<int>? claritySeries,
    List<String>? gaps,
  }) =>
      FeynmanSession(
        id: id,
        conceptId: conceptId,
        conceptName: conceptName,
        version: version,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
        transcript: transcript ?? this.transcript,
        claritySeries: claritySeries ?? this.claritySeries,
        gaps: gaps ?? this.gaps,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'conceptId': conceptId,
        'conceptName': conceptName,
        'version': version,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'transcript': transcript.map((e) => e.toJson()).toList(),
        'claritySeries': claritySeries,
        'gaps': gaps,
      };

  factory FeynmanSession.fromJson(Map<String, dynamic> json) => FeynmanSession(
        id: json['id'] as String,
        conceptId: json['conceptId'] as String,
        conceptName: json['conceptName'] as String,
        version: (json['version'] as num?)?.toInt() ?? 1,
        startedAt: DateTime.parse(json['startedAt'] as String),
        endedAt: json['endedAt'] != null
            ? DateTime.tryParse(json['endedAt'] as String)
            : null,
        transcript: <TranscriptEntry>[
          for (final e in (json['transcript'] as List? ?? const []))
            TranscriptEntry.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
        claritySeries: <int>[
          for (final c in (json['claritySeries'] as List? ?? const []))
            (c as num).toInt(),
        ],
        gaps: <String>[
          for (final g in (json['gaps'] as List? ?? const []))
            if (g is String) g,
        ],
      );
}
