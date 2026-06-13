import 'dart:convert';

import 'package:hive/hive.dart';

import '../domain/curated_plan.dart';

/// Persistence boundary for the single generated study plan. Same approach as
/// the session and profile repositories: one Hive box of JSON strings.
abstract interface class PlanRepository {
  /// The saved plan, or null if one has never been generated.
  CuratedPlan? get();

  Future<void> save(CuratedPlan plan);

  /// Drop the plan — forces regeneration (e.g. after re-onboarding).
  Future<void> clear();
}

class HivePlanRepository implements PlanRepository {
  HivePlanRepository(this._box);

  static const boxName = 'curated_plan';
  static const _key = 'plan';

  final Box<String> _box;

  /// Open the box. Call once at startup after `Hive.initFlutter()`.
  static Future<HivePlanRepository> open() async {
    final box = await Hive.openBox<String>(boxName);
    return HivePlanRepository(box);
  }

  @override
  CuratedPlan? get() {
    final raw = _box.get(_key);
    if (raw == null) return null;
    try {
      return CuratedPlan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(CuratedPlan plan) =>
      _box.put(_key, jsonEncode(plan.toJson()));

  @override
  Future<void> clear() => _box.delete(_key);
}
