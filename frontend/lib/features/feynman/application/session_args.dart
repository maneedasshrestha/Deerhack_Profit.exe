/// Identifies which concept/version a live session is teaching. Used as the
/// family key for [feynmanControllerProvider], so equality matters — two args
/// with the same fields share one controller instance.
class SessionArgs {
  const SessionArgs({
    required this.conceptId,
    required this.conceptName,
    required this.version,
  });

  final String conceptId;
  final String conceptName;
  final int version;

  @override
  bool operator ==(Object other) =>
      other is SessionArgs &&
      other.conceptId == conceptId &&
      other.conceptName == conceptName &&
      other.version == version;

  @override
  int get hashCode => Object.hash(conceptId, conceptName, version);
}
