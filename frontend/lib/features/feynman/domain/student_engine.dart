import 'models/student_turn.dart';

/// One prior turn of context sent to the engine.
class EngineTurn {
  const EngineTurn({required this.isStudent, required this.text});

  /// false = the learner's explanation, true = the student's question.
  final bool isStudent;
  final String text;

  Map<String, dynamic> toJson() => {
        'role': isStudent ? 'student' : 'user',
        'text': text,
      };
}

/// Everything the engine needs to produce the next student turn.
class StudentRequest {
  const StudentRequest({
    required this.concept,
    required this.explanation,
    this.history = const [],
  });

  final String concept;
  final String explanation;
  final List<EngineTurn> history;
}

/// The voice/LLM seam. The UI and state machine depend ONLY on this interface,
/// never on how the reply is produced.
///
/// Today there is one implementation — [TurnBasedStudentEngine] (and a
/// [MockStudentEngine] for offline/dev). The point of the interface is that a
/// streaming realtime backend (Gemini Live / OpenAI Realtime over WebSocket)
/// can be dropped in later as a new `StreamingStudentEngine implements
/// StudentEngine` with no change to the orb, the state machine, or the UI. The
/// turn-based `Future<StudentTurn>` is the lowest common denominator both can
/// satisfy.
abstract interface class StudentEngine {
  /// Produce the next student turn for the given explanation. May throw on
  /// network/parse failure; callers fall back to [StudentTurn.fallback].
  Future<StudentTurn> respond(StudentRequest request);
}
