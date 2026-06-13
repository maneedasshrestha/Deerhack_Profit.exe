import 'dart:math';

import '../../domain/models/student_turn.dart';
import '../../domain/student_engine.dart';

/// Offline / dev engine. Implements the SAME interface as the real one so the
/// full loop runs end-to-end with no backend. It is deliberately a little
/// heuristic-clever — it pulls plausible "jargon" out of the learner's own
/// words and scales clarity with how much plain language they used — so the
/// reflection view (underlines, sparkline) has real-looking data to render.
class MockStudentEngine implements StudentEngine {
  MockStudentEngine({Duration? thinkingDelay, Random? random})
      : _thinkingDelay = thinkingDelay ?? const Duration(milliseconds: 1100),
        _rng = random ?? Random();

  final Duration _thinkingDelay;
  final Random _rng;

  // Words a curious kid would already know — never flagged as jargon. Includes
  // ordinary "explaining" words (because/example/different/…) so the act of
  // explaining a term doesn't itself trip the jargon detector.
  static const _common = {
    'the', 'and', 'that', 'this', 'with', 'from', 'into', 'when', 'then',
    'they', 'have', 'what', 'which', 'because', 'about', 'there', 'their',
    'would', 'could', 'really', 'kind', 'like', 'just', 'some', 'more',
    'water', 'light', 'energy', 'plant', 'food', 'heat', 'cold', 'fast',
    'slow', 'small', 'big', 'happens', 'makes', 'turns', 'moves',
    // Common explanatory / filler words — long enough to look like jargon but
    // not actually technical terms.
    'basically', 'actually', 'something', 'someone', 'different', 'example',
    'examples', 'important', 'explain', 'explains', 'explained', 'explanation',
    'through', 'between', 'another', 'without', 'sometimes', 'usually',
    'generally', 'essentially', 'represents', 'represent', 'process', 'little',
    'around', 'against', 'therefore', 'however', 'meaning', 'means', 'called',
    'basic', 'simple', 'simply', 'thing', 'things', 'where', 'while', 'these',
    'those', 'using', 'used', 'uses', 'amount', 'number', 'inside', 'outside',
    'together', 'instead', 'becomes', 'become', 'change', 'changes', 'whenever',
  };

  static const _reactions = [
    'Oh okay, I think I sort of get it...',
    'Wait, that almost makes sense to me.',
    'Hmm, interesting!',
    'Okay okay, keep going...',
    'Ohh, so it’s kind of like that?',
  ];

  @override
  Future<StudentTurn> respond(StudentRequest request) async {
    // Simulate the network/model "thinking" pause so the UI behaves identically.
    await Future<void>.delayed(_thinkingDelay);

    final words = _tokenize(request.explanation);

    // Terms already in play — the concept being taught, plus everything the
    // learner said in earlier explanations. A word that's already been raised
    // (and, by now, asked about) must NOT be flagged again, or explaining a
    // buzzword would just surface the same buzzword and loop forever.
    final addressed = <String>{
      for (final w in _tokenize(request.concept)) w.toLowerCase(),
      for (final turn in request.history)
        if (!turn.isStudent)
          for (final w in _tokenize(turn.text)) w.toLowerCase(),
    };

    final jargon = _detectJargon(words, addressed);
    final clarity = _scoreClarity(words, jargon);
    final reaction = _reactions[_rng.nextInt(_reactions.length)];
    final question = _composeQuestion(jargon, request.concept);

    return StudentTurn(
      reaction: reaction,
      question: question,
      clarity: clarity,
      jargon: jargon,
    );
  }

  /// Splits text into bare words, dropping punctuation/markdown emphasis.
  List<String> _tokenize(String text) => text
      .split(RegExp(r'[\s.,;:!?()"*_]+'))
      .where((w) => w.isNotEmpty)
      .toList();

  /// Picks up to three NEW long words to ask about. [addressed] holds terms
  /// already raised earlier in the session (concept name + prior explanations);
  /// those are skipped so a term is only ever questioned once.
  List<String> _detectJargon(List<String> words, Set<String> addressed) {
    final seen = <String>{};
    final result = <String>[];
    for (final w in words) {
      final lower = w.toLowerCase();
      if (lower.length < 7) continue; // short words are rarely jargon
      if (_common.contains(lower)) continue;
      if (addressed.contains(lower)) continue; // already asked about earlier
      if (seen.contains(lower)) continue;
      seen.add(lower);
      result.add(w);
      if (result.length >= 3) break;
    }
    return result;
  }

  int _scoreClarity(List<String> words, List<String> jargon) {
    if (words.isEmpty) return 20;
    // Reward longer, plainer explanations; penalise unexplained jargon.
    final lengthBonus = min(40, words.length); // up to +40 for ~40 words
    final jargonPenalty = jargon.length * 12;
    final base = 45 + lengthBonus - jargonPenalty + _rng.nextInt(10) - 5;
    return base.clamp(10, 96);
  }

  String _composeQuestion(List<String> jargon, String concept) {
    if (jargon.isNotEmpty) {
      final term = jargon.first;
      final templates = [
        "But what actually *is* '$term'? What does it do?",
        "Wait, you said '$term' — can you explain that bit without the big word?",
        "What does '$term' mean? I’ve never heard that before.",
      ];
      return templates[_rng.nextInt(templates.length)];
    }
    final fallbacks = [
      'But why does that happen, though?',
      'Okay, but what would happen if you didn’t do that?',
      'Can you give me a tiny example so I can picture it?',
      'What’s the most important part to remember about $concept?',
    ];
    return fallbacks[_rng.nextInt(fallbacks.length)];
  }
}
