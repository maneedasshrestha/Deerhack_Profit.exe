import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../feynman/application/providers.dart' show appConfigProvider;
import '../data/plan_repository.dart';
import '../data/plan_service.dart';
import '../domain/curated_plan.dart';

/// Injected at startup in main.dart (same pattern as the other repositories).
final planRepositoryProvider = Provider<PlanRepository>((ref) {
  throw UnimplementedError('planRepositoryProvider must be overridden');
});

/// Real backend planner, or the offline mock — chosen by the same [AppConfig]
/// that the Feynman engine uses, so one flag controls both.
final planServiceProvider = Provider<PlanService>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockEngine) return const MockPlanService();
  final service = HttpPlanService(baseUrl: config.proxyBaseUrl);
  ref.onDispose(service.dispose);
  return service;
});

/// The generated plan, or null while it still needs building. The app shell
/// watches this: profile set + plan null → loading screen; plan set → main app.
class CuratedPlanNotifier extends StateNotifier<CuratedPlan?> {
  CuratedPlanNotifier(this._repo) : super(_repo.get());

  final PlanRepository _repo;

  Future<void> complete(CuratedPlan plan) async {
    await _repo.save(plan);
    state = plan;
  }

  Future<void> clear() async {
    await _repo.clear();
    state = null;
  }
}

final curatedPlanProvider =
    StateNotifierProvider<CuratedPlanNotifier, CuratedPlan?>(
        (ref) => CuratedPlanNotifier(ref.watch(planRepositoryProvider)));
