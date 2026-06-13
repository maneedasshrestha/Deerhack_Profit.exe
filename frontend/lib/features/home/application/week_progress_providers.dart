import 'package:flutter_riverpod/flutter_riverpod.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Week progression state — which levels the learner has cleared this week, and
// the stars they earned. The home path watches this and re-derives each node's
// locked/current/completed status (see applyProgress), so finishing a level
// unlocks the next and lights up the mascot in the gap above it.
//
// In-memory for now (resets on restart); swap the notifier's backing store for
// Hive later with no change to the screens that read it.
// ═══════════════════════════════════════════════════════════════════════════
class WeekProgressNotifier extends StateNotifier<Map<String, int>> {
  WeekProgressNotifier() : super(const {});

  /// Records [levelId] as complete, keeping the best star count if it's been
  /// cleared before. Triggers a rebuild that unlocks the following level.
  void complete(String levelId, {int stars = 3}) {
    final best = state[levelId];
    if (best != null && best >= stars) return;
    state = {...state, levelId: stars};
  }

  bool isComplete(String levelId) => state.containsKey(levelId);

  /// Clears the week — used when a new week's plan replaces the current one.
  void reset() => state = const {};
}

final weekProgressProvider =
    StateNotifierProvider<WeekProgressNotifier, Map<String, int>>(
        (ref) => WeekProgressNotifier());
