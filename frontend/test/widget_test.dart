// Domain-level tests for the Feynman feature. These cover the defensive
// parsing and persistence invariants the spec calls out — no plugins needed.

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/feynman/data/engine/mock_student_engine.dart';
import 'package:frontend/features/feynman/domain/models/feynman_session.dart';
import 'package:frontend/features/feynman/domain/models/student_turn.dart';
import 'package:frontend/features/feynman/domain/models/transcript_entry.dart';
import 'package:frontend/features/feynman/domain/student_engine.dart';

void main() {
  group('StudentTurn.fromJson defensive parsing', () {
    test('clamps clarity above 100 and below 0', () {
      expect(StudentTurn.fromJson({'clarity': 250}).clarity, 100);
      expect(StudentTurn.fromJson({'clarity': -40}).clarity, 0);
    });

    test('tolerates string / double clarity', () {
      expect(StudentTurn.fromJson({'clarity': '73'}).clarity, 73);
      expect(StudentTurn.fromJson({'clarity': 61.7}).clarity, 62);
    });

    test('supplies a fallback question when missing or blank', () {
      expect(StudentTurn.fromJson({}).question, isNotEmpty);
      expect(StudentTurn.fromJson({'question': '   '}).question, isNotEmpty);
    });

    test('drops blank jargon entries', () {
      final turn = StudentTurn.fromJson({
        'jargon': ['photophosphorylation', '', '  ', 42],
      });
      expect(turn.jargon, ['photophosphorylation']);
    });
  });

  group('MockStudentEngine', () {
    test('flags long unexplained words and scores clarity in range', () async {
      final engine = MockStudentEngine(thinkingDelay: Duration.zero);
      final turn = await engine.respond(const StudentRequest(
        concept: 'photosynthesis',
        explanation:
            'Plants use chlorophyll inside the thylakoid membrane to capture light.',
      ));
      expect(turn.clarity, inInclusiveRange(0, 100));
      expect(turn.jargon, isNotEmpty);
      expect(turn.question, isNotEmpty);
    });
  });

  group('FeynmanSession JSON round-trip', () {
    test('survives serialise → deserialise', () {
      final session = FeynmanSession(
        id: 'photosynthesis-v1-123',
        conceptId: 'photosynthesis-123',
        conceptName: 'photosynthesis',
        version: 1,
        startedAt: DateTime(2026, 6, 12, 10, 30),
        endedAt: DateTime(2026, 6, 12, 10, 45),
        transcript: [
          TranscriptEntry(
            speaker: Speaker.learner,
            text: 'Plants make food from light.',
            jargon: const ['chlorophyll'],
            clarity: 72,
            at: DateTime(2026, 6, 12, 10, 31),
          ),
          TranscriptEntry(
            speaker: Speaker.student,
            text: 'What is chlorophyll?',
            reaction: 'Oh okay...',
            at: DateTime(2026, 6, 12, 10, 32),
          ),
        ],
        claritySeries: const [72],
        gaps: const ['chlorophyll'],
      );

      final restored = FeynmanSession.fromJson(session.toJson());
      expect(restored.conceptName, 'photosynthesis');
      expect(restored.version, 1);
      expect(restored.finalClarity, 72);
      expect(restored.gaps, ['chlorophyll']);
      expect(restored.transcript.first.jargon, ['chlorophyll']);
      expect(restored.transcript.last.reaction, 'Oh okay...');
    });
  });
}
