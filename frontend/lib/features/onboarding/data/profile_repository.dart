import 'dart:convert';

import 'package:hive/hive.dart';

import '../domain/user_profile.dart';

/// Persistence boundary for the single onboarding profile. Mirrors the session
/// repository: one Hive box of JSON strings, no typed adapters / codegen.
abstract interface class ProfileRepository {
  /// The saved profile, or null if onboarding has never been completed.
  UserProfile? get();

  Future<void> save(UserProfile profile);

  /// Wipe the profile — sends the learner back through onboarding.
  Future<void> clear();
}

class HiveProfileRepository implements ProfileRepository {
  HiveProfileRepository(this._box);

  static const boxName = 'user_profile';
  static const _key = 'profile';

  final Box<String> _box;

  /// Open the box. Call once at startup after `Hive.initFlutter()`.
  static Future<HiveProfileRepository> open() async {
    final box = await Hive.openBox<String>(boxName);
    return HiveProfileRepository(box);
  }

  @override
  UserProfile? get() {
    final raw = _box.get(_key);
    if (raw == null) return null;
    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A corrupt record shouldn't trap the learner — treat it as no profile.
      return null;
    }
  }

  @override
  Future<void> save(UserProfile profile) =>
      _box.put(_key, jsonEncode(profile.toJson()));

  @override
  Future<void> clear() => _box.delete(_key);
}
