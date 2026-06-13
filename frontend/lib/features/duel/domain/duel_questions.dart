import 'dart:math';

import '../../home/domain/mock_data.dart';

/// Builds and resolves the question set for a duel. Both players answer an
/// identical, ordered set: the challenger picks it once (storing the explicit
/// question ids on the duel), and every client resolves those ids back to the
/// bundled question bank — so questions stay in sync without a backend table.
class DuelQuestions {
  DuelQuestions._();

  static const int perDuel = 5;

  /// Topics a duel can draw from, each a slice of the bundled bank.
  static final Map<String, List<MockQuestion>> _topics = {
    'Work & Energy': MockData.workEnergyQuestions,
    'Derivatives': MockData.derivativesQuestions,
    'Chemical Bonding': MockData.chemistryQuestions,
    'Prose & Grammar': MockData.englishQuestions,
  };

  static final Map<String, MockQuestion> _byId = {
    for (final q in MockData.allQuestions) q.id: q,
  };

  /// Pick a random topic + an ordered set of question ids for a new duel.
  /// Tops up from the wider bank if a topic has fewer than [perDuel] questions.
  static ({String topic, List<String> questionIds}) pick([Random? rng]) {
    final random = rng ?? Random();
    final topics = _topics.keys.toList();
    final topic = topics[random.nextInt(topics.length)];

    final ids = <String>[
      for (final q in _topics[topic]!) q.id,
    ];
    if (ids.length < perDuel) {
      for (final q in MockData.allQuestions) {
        if (ids.length >= perDuel) break;
        if (!ids.contains(q.id)) ids.add(q.id);
      }
    }
    return (topic: topic, questionIds: ids.take(perDuel).toList());
  }

  /// Resolve stored question ids back to questions, dropping any unknown ids.
  static List<MockQuestion> resolve(List<String> ids) =>
      [for (final id in ids) if (_byId[id] != null) _byId[id]!];
}
