import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/haptics.dart';
import '../data/engine/turn_based_student_engine.dart';
import '../data/repository/session_repository.dart';
import '../domain/models/feynman_phase.dart';
import '../domain/models/feynman_session.dart';
import '../domain/models/feynman_state.dart';
import '../domain/models/student_turn.dart';
import '../domain/models/transcript_entry.dart';
import '../domain/student_engine.dart';
import 'session_args.dart';
import 'speech_service.dart';
import 'voice_service.dart';

/// Owns every transition of the Feynman loop. The UI never mutates state — it
/// calls intent methods here and renders [state] purely.
///
/// Invariant the machine enforces: exactly one of STT / TTS is active at a time.
/// Before the student speaks we stop the recognizer; we only reopen the mic
/// once TTS reports completion. That kills the mic→speaker→mic feedback loop.
class FeynmanController extends StateNotifier<FeynmanState> {
  FeynmanController({
    required this.args,
    required StudentEngine engine,
    required SpeechService speech,
    required VoiceService voice,
    required SessionRepository repository,
  })  : _engine = engine,
        _speech = speech,
        _voice = voice,
        _repo = repository,
        super(FeynmanState.initial(
          conceptId: args.conceptId,
          conceptName: args.conceptName,
          version: args.version,
          startedAt: DateTime.now(),
        ));

  final SessionArgs args;
  final StudentEngine _engine;
  final SpeechService _speech;
  final VoiceService _voice;
  final SessionRepository _repo;

  bool _finalizing = false; // guards double-submit on manual+auto stop
  bool _saved = false;
  String _heard = ''; // latest recognized words this listen session
  double _smoothedLevel = 0;

  // ── Mic control ──────────────────────────────────────────────────────────

  /// Single entry point for the big mic button. Idle → start; listening → stop.
  Future<void> toggleMic() async {
    final phase = state.phase;
    if (phase is ListeningPhase) {
      await _finishListening();
    } else if (phase is IdlePhase || phase is SessionErrorPhase) {
      await beginListening();
    }
    // While transcribing/thinking/speaking the button is disabled.
  }

  Future<void> beginListening() async {
    final availability = await _speech.ensureInitialized();
    switch (availability) {
      case SpeechAvailability.denied:
        state = state.copyWith(
          phase: const SessionErrorPhase(
            message: 'Microphone access is off. You can type your explanation '
                'instead, or enable the mic in Settings.',
            recoverable: true,
          ),
        );
        return;
      case SpeechAvailability.unavailable:
        state = state.copyWith(
          phase: const SessionErrorPhase(
            message: 'Speech recognition isn’t available on this device. '
                'You can type your explanation instead.',
            recoverable: true,
          ),
        );
        return;
      case SpeechAvailability.ready:
        break;
    }

    _heard = '';
    _finalizing = false;
    _smoothedLevel = 0;
    state = state.copyWith(phase: const ListeningPhase(), caption: '', soundLevel: 0);

    await _speech.listen(
      onResult: (text, isFinal) {
        _heard = text;
        if (!mounted) return;
        state = state.copyWith(caption: text);
        if (isFinal) _finalize(text);
      },
      onLevel: (level) {
        // Smooth the amplitude so the orb glides rather than jitters.
        _smoothedLevel = _smoothedLevel * 0.7 + level * 0.3;
        if (!mounted) return;
        if (state.phase is ListeningPhase) {
          state = state.copyWith(soundLevel: _smoothedLevel);
        }
      },
      onError: (message, {noSpeech = false}) {
        if (!mounted) return;
        if (noSpeech) {
          // Give the learner explicit feedback instead of silently idling —
          // on an emulator with no working mic this is the usual outcome.
          state = state.copyWith(
            phase: const SessionErrorPhase(
              message: "I didn't hear anything. Check the mic, or tap the "
                  'keyboard below to type instead.',
              retryListening: true,
            ),
            caption: '',
            soundLevel: 0,
          );
        } else {
          state = state.copyWith(
            phase: SessionErrorPhase(message: message, retryListening: true),
            soundLevel: 0,
          );
        }
      },
      onDone: () {
        // Recognizer stopped on its own (pause window elapsed).
        if (state.phase is ListeningPhase) _finalize(_heard);
      },
    );
  }

  Future<void> _finishListening() async {
    await _speech.stop();
    _finalize(_heard);
  }

  void _finalize(String text) {
    if (_finalizing) return;
    _finalizing = true;
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      // Heard nothing — tell the learner rather than silently resetting.
      state = state.copyWith(
        phase: const SessionErrorPhase(
          message: "I didn't catch that. Tap the orb to try again, or use the "
              'keyboard to type.',
          retryListening: true,
        ),
        caption: '',
        soundLevel: 0,
      );
      _finalizing = false;
      return;
    }
    state = state.copyWith(phase: const TranscribingPhase(), soundLevel: 0);
    _processExplanation(trimmed);
  }

  // ── Typed fallback ─────────────────────────────────────────────────────────

  /// Secondary input path (mic denied, or the learner prefers typing).
  Future<void> submitTyped(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.phase.isBusy || state.phase.isSpeaking) return;
    _finalizing = true;
    state = state.copyWith(phase: const TranscribingPhase(), caption: trimmed);
    await _processExplanation(trimmed);
  }

  // ── Core turn processing ───────────────────────────────────────────────────

  Future<void> _processExplanation(String explanation) async {
    // History is everything BEFORE this explanation.
    final history = [
      for (final e in state.transcript) EngineTurn(isStudent: !e.isLearner, text: e.text),
    ];

    final learnerEntry = TranscriptEntry(
      speaker: Speaker.learner,
      text: explanation,
      at: DateTime.now(),
    );
    state = state.copyWith(
      transcript: [...state.transcript, learnerEntry],
      phase: const StudentThinkingPhase(),
      caption: '',
    );
    _finalizing = false;

    StudentTurn turn;
    try {
      turn = await _engine.respond(StudentRequest(
        concept: state.conceptName,
        explanation: explanation,
        history: history,
      ));
    } on StudentEngineException catch (e) {
      // Network/model failure: keep the transcript, surface a recoverable error.
      if (!mounted) return;
      state = state.copyWith(
        phase: SessionErrorPhase(message: e.message, recoverable: true),
      );
      return;
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        phase: const SessionErrorPhase(
          message: 'Something went wrong reaching the student.',
          recoverable: true,
        ),
      );
      return;
    }

    if (!mounted) return;
    _applyTurn(turn);
    await _speak(turn);
  }

  /// Re-run the engine for the most recent learner turn that has no reply yet.
  /// Used by the error view's "try again".
  Future<void> retryLastTurn() async {
    final lastLearner = _pendingLearnerExplanation();
    if (lastLearner == null) {
      state = state.copyWith(phase: const IdlePhase());
      return;
    }
    // Drop the dangling learner entry; _processExplanation re-adds it cleanly.
    final trimmedTranscript = [...state.transcript]..removeLast();
    state = state.copyWith(
      transcript: trimmedTranscript,
      phase: const StudentThinkingPhase(),
    );
    await _processExplanation(lastLearner);
  }

  String? _pendingLearnerExplanation() {
    if (state.transcript.isEmpty) return null;
    final last = state.transcript.last;
    return last.isLearner ? last.text : null;
  }

  void _applyTurn(StudentTurn turn) {
    final transcript = [...state.transcript];
    // Attach jargon + clarity to the learner turn we just sent.
    final lastIndex = transcript.lastIndexWhere((e) => e.isLearner);
    if (lastIndex != -1) {
      transcript[lastIndex] = transcript[lastIndex]
          .copyWith(jargon: turn.jargon, clarity: turn.clarity);
    }
    // Append the student's turn.
    transcript.add(TranscriptEntry(
      speaker: Speaker.student,
      text: turn.question,
      reaction: turn.reaction,
      at: DateTime.now(),
    ));

    // Merge unique gaps (case-insensitive).
    final gaps = [...state.gaps];
    for (final term in turn.jargon) {
      final exists = gaps.any((g) => g.toLowerCase() == term.toLowerCase());
      if (!exists) gaps.add(term);
    }

    state = state.copyWith(
      transcript: transcript,
      claritySeries: [...state.claritySeries, turn.clarity],
      gaps: gaps,
      phase: StudentSpeakingPhase(reaction: turn.reaction, question: turn.question),
    );
  }

  Future<void> _speak(StudentTurn turn) async {
    await _voice.speak(turn.spoken);
    if (!mounted) return;
    await Haptics.studentDoneSpeaking();
    state = state.copyWith(phase: const IdlePhase(), soundLevel: 0);
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  /// Build, persist, and return the session artifact. Safe to call once.
  Future<FeynmanSession> endSession() async {
    await _speech.cancel();
    await _voice.stop();
    await Haptics.sessionEnd();

    final session = FeynmanSession(
      id: '${state.conceptId}-v${state.version}-${state.startedAt.microsecondsSinceEpoch}',
      conceptId: state.conceptId,
      conceptName: state.conceptName,
      version: state.version,
      startedAt: state.startedAt,
      endedAt: DateTime.now(),
      transcript: state.transcript,
      claritySeries: state.claritySeries,
      gaps: state.gaps,
    );

    if (!_saved) {
      _saved = true;
      try {
        await _repo.save(session);
      } catch (e) {
        debugPrint('Failed to persist session: $e');
      }
    }
    return session;
  }

  /// Called when the live screen is disposed without an explicit end (back nav).
  Future<void> disposeServices() async {
    await _speech.cancel();
    await _voice.stop();
  }
}
