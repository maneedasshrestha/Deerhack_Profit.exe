/// The Feynman loop, modelled explicitly as a state machine:
///
///   idle → listening → transcribing → studentThinking → studentSpeaking → idle
///                                                            ↑____repeat____|
///
/// The UI is a pure function of the current phase. Exactly one of STT / TTS is
/// active at a time, gated by which phase we're in.
sealed class FeynmanPhase {
  const FeynmanPhase();
}

/// Mic is off; waiting for the learner to tap to speak (or to finish a turn).
class IdlePhase extends FeynmanPhase {
  const IdlePhase();
}

/// Mic is open; STT is capturing. The orb reacts to amplitude.
class ListeningPhase extends FeynmanPhase {
  const ListeningPhase();
}

/// Mic just closed; we're finalising the last words before sending.
class TranscribingPhase extends FeynmanPhase {
  const TranscribingPhase();
}

/// Explanation sent to the engine; awaiting the student's reply. The orb stays
/// gently animated so the pause never reads as "frozen".
class StudentThinkingPhase extends FeynmanPhase {
  const StudentThinkingPhase();
}

/// TTS is speaking the student's reaction + question. The orb "breathes".
class StudentSpeakingPhase extends FeynmanPhase {
  const StudentSpeakingPhase({required this.reaction, required this.question});

  final String reaction;
  final String question;
}

/// A recoverable problem (network failure, no speech detected, permission
/// denied). [recoverable] controls whether the UI offers a retry vs. an exit.
///
/// [retryListening] disambiguates what "try again" should do:
///   * true  → restart the microphone (no speech detected, mic glitch)
///   * false → re-send the last explanation to the engine (network/model error)
class SessionErrorPhase extends FeynmanPhase {
  const SessionErrorPhase({
    required this.message,
    this.recoverable = true,
    this.retryListening = false,
  });

  final String message;
  final bool recoverable;
  final bool retryListening;
}

/// Coarse visual mode for the orb. Several phases map to the same orb look.
enum OrbMode { idle, listening, thinking, speaking }

extension FeynmanPhaseX on FeynmanPhase {
  OrbMode get orbMode => switch (this) {
        IdlePhase() => OrbMode.idle,
        ListeningPhase() => OrbMode.listening,
        TranscribingPhase() => OrbMode.thinking,
        StudentThinkingPhase() => OrbMode.thinking,
        StudentSpeakingPhase() => OrbMode.speaking,
        SessionErrorPhase() => OrbMode.idle,
      };

  bool get isListening => this is ListeningPhase;
  bool get isBusy => this is TranscribingPhase || this is StudentThinkingPhase;
  bool get isSpeaking => this is StudentSpeakingPhase;
  bool get isError => this is SessionErrorPhase;
}
