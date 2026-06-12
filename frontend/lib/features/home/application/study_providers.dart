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
