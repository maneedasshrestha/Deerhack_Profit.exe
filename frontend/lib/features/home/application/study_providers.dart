import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/mock_data.dart';

/// Question ids the learner has starred as important. Starred questions are
/// togglable from any lesson and resurface on the profile for quick revision.
class StarredQuestionsNotifier extends StateNotifier<Set<String>> {
  StarredQuestionsNotifier() : super({'q2', 'dq4', 'cq2'});

  void toggle(String id) {
    state = state.contains(id)
        ? ({...state}..remove(id))
        : {...state, id};
  }

  bool isStarred(String id) => state.contains(id);
}

final starredQuestionsProvider =
    StateNotifierProvider<StarredQuestionsNotifier, Set<String>>(
        (ref) => StarredQuestionsNotifier());

/// The full [MockQuestion] objects for the starred ids, in bank order.
final starredQuestionListProvider = Provider<List<MockQuestion>>((ref) {
  final ids = ref.watch(starredQuestionsProvider);
  return MockData.allQuestions.where((q) => ids.contains(q.id)).toList();
});

/// The learner's daily streak. Seeded from [MockData.streak] and extended the
/// first time they finish a day's practice — later completions the same day
/// keep it steady (you can't earn two days of streak in one day).
class StreakNotifier extends StateNotifier<int> {
  StreakNotifier() : super(MockData.streak);

  bool _countedToday = false;

  /// Records that today's MCQs were completed. Increments the streak only on
  /// the first completion of the day. Returns the streak value *before* this
  /// call so the celebration can roll the number from old → new.
  int registerDayComplete() {
    final before = state;
    if (!_countedToday) {
      _countedToday = true;
      state = state + 1;
    }
    return before;
  }
}

final streakProvider =
    StateNotifierProvider<StreakNotifier, int>((ref) => StreakNotifier());
