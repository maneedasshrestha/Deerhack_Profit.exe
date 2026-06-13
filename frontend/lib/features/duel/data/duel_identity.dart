import 'dart:math';

import 'package:hive/hive.dart';

import '../domain/duel_player.dart';

// ═══════════════════════════════════════════════════════════════════════════
// DuelIdentity — the local player's stable id for duels. Real Supabase auth is
// not gated here (decision: mock-but-stable identity), so we mint a UUID once,
// store it in Hive, and reuse it across launches. The display name is supplied
// by the caller (the onboarding profile, falling back to a default).
// ═══════════════════════════════════════════════════════════════════════════
class DuelIdentity {
  DuelIdentity(this._box);

  static const boxName = 'duel_identity';
  static const _idKey = 'player_id';

  final Box<String> _box;

  static Future<DuelIdentity> open() async {
    final box = await Hive.openBox<String>(boxName);
    return DuelIdentity(box);
  }

  /// The stable local player id, minted on first use.
  String get playerId {
    final existing = _box.get(_idKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _newUuidV4();
    _box.put(_idKey, id);
    return id;
  }

  /// Build the player row for [displayName], using the stored id. [photoUrl]
  /// should be a shareable network URL (or null) — see [DuelPlayer.photoUrl].
  DuelPlayer playerFor(String displayName, {String? photoUrl}) {
    final name = displayName.trim().isEmpty ? 'Player' : displayName.trim();
    return DuelPlayer(
      id: playerId,
      displayName: name,
      initials: DuelPlayer.initialsFor(name),
      photoUrl: photoUrl,
    );
  }

  // RFC-4122 v4 UUID from Dart's PRNG. Not crypto-grade, but plenty unique for
  // a device-local identity (we don't depend on a uuid package).
  static String _newUuidV4() {
    final rng = Random();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
