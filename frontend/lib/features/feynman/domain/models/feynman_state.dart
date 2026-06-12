import 'feynman_phase.dart';
import 'transcript_entry.dart';

/// The complete, immutable state of a live session. The UI renders purely from
/// this. The controller owns all transitions.
///
/// Note we keep BOTH the ephemeral live bits (phase, caption, soundLevel) and
/// the durable artifact (transcript, clarity series, gaps) in one object — the
/// reflection payload is always being accumulated, never thrown away.
class FeynmanState {
  const FeynmanState({
    required this.conceptId,
    required this.conceptName,
    required this.version,
    required this.phase,
    required this.transcript,
    required this.claritySeries,
    required this.gaps,
    required this.caption,
    required this.soundLevel,
    required this.startedAt,
  });

  factory FeynmanState.initial({
    required String conceptId,
    required String conceptName,
    required int version,
    required DateTime startedAt,
  }) =>
      FeynmanState(
        conceptId: conceptId,
        conceptName: conceptName,
        version: version,
        phase: const IdlePhase(),
        transcript: const [],
        claritySeries: const [],
        gaps: const [],
        caption: '',
        soundLevel: 0,
        startedAt: startedAt,
      );

  final String conceptId;
  final String conceptName;
  final int version;

  final FeynmanPhase phase;

  /// The conversation so far — the artifact that survives the session.
  final List<TranscriptEntry> transcript;

  /// Clarity per learner turn, in order. Drives score + sparkline.
  final List<int> claritySeries;

  /// Unique flagged jargon across the session. Drives the "N gaps" counter.
  final List<String> gaps;

  /// The learner's most recent words, shown as live caption while listening.
  final String caption;

  /// 0..1 normalised mic level, drives the listening orb amplitude.
  final double soundLevel;

  final DateTime startedAt;

  int get currentClarity => claritySeries.isNotEmpty ? claritySeries.last : 0;
  int get gapCount => gaps.length;
  bool get hasContent => transcript.any((e) => e.isLearner);

  FeynmanState copyWith({
    FeynmanPhase? phase,
    List<TranscriptEntry>? transcript,
    List<int>? claritySeries,
    List<String>? gaps,
    String? caption,
    double? soundLevel,
  }) =>
      FeynmanState(
        conceptId: conceptId,
        conceptName: conceptName,
        version: version,
        phase: phase ?? this.phase,
        transcript: transcript ?? this.transcript,
        claritySeries: claritySeries ?? this.claritySeries,
        gaps: gaps ?? this.gaps,
        caption: caption ?? this.caption,
        soundLevel: soundLevel ?? this.soundLevel,
        startedAt: startedAt,
      );
}
