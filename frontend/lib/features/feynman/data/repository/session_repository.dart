import 'dart:convert';

import 'package:hive/hive.dart';

import '../../domain/models/feynman_session.dart';

/// Persistence boundary for sessions and their versioned attempts.
abstract interface class SessionRepository {
  Future<void> save(FeynmanSession session);

  /// All attempts at one concept, oldest version first.
  List<FeynmanSession> versionsOf(String conceptId);

  /// The latest attempt of every distinct concept, most recently practised
  /// first — for the "recent concepts" list on the setup screen.
  List<FeynmanSession> latestPerConcept();

  /// The next version number to assign for a concept (1 if brand new).
  int nextVersion(String conceptId);

  /// Find an existing concept id by name (case-insensitive), so re-teaching the
  /// same concept versions onto the same history. Null if never taught.
  String? conceptIdForName(String name);

  FeynmanSession? byId(String id);
}

/// Hive-backed implementation. We store each session as a JSON string keyed by
/// its id — no typed adapters / code generation needed, which keeps the build
/// simple while the data stays small and structured.
class HiveSessionRepository implements SessionRepository {
  HiveSessionRepository(this._box);

  static const boxName = 'feynman_sessions';

  final Box<String> _box;

  /// Open the box. Call once at startup after `Hive.initFlutter()`.
  static Future<HiveSessionRepository> open() async {
    final box = await Hive.openBox<String>(boxName);
    return HiveSessionRepository(box);
  }

  List<FeynmanSession> _all() {
    final out = <FeynmanSession>[];
    for (final raw in _box.values) {
      try {
        out.add(FeynmanSession.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Skip any corrupt record rather than crash the list.
      }
    }
    return out;
  }

  @override
  Future<void> save(FeynmanSession session) =>
      _box.put(session.id, jsonEncode(session.toJson()));

  @override
  List<FeynmanSession> versionsOf(String conceptId) {
    final list = _all().where((s) => s.conceptId == conceptId).toList()
      ..sort((a, b) => a.version.compareTo(b.version));
    return list;
  }

  @override
  List<FeynmanSession> latestPerConcept() {
    final latest = <String, FeynmanSession>{};
    for (final s in _all()) {
      final existing = latest[s.conceptId];
      if (existing == null || s.version > existing.version) {
        latest[s.conceptId] = s;
      }
    }
    final list = latest.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return list;
  }

  @override
  int nextVersion(String conceptId) {
    final versions = versionsOf(conceptId);
    if (versions.isEmpty) return 1;
    return versions.last.version + 1;
  }

  @override
  String? conceptIdForName(String name) {
    final target = name.trim().toLowerCase();
    for (final s in _all()) {
      if (s.conceptName.trim().toLowerCase() == target) return s.conceptId;
    }
    return null;
  }

  @override
  FeynmanSession? byId(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    try {
      return FeynmanSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
