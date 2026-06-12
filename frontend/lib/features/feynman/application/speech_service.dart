import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Outcome of trying to initialise speech recognition.
enum SpeechAvailability { ready, denied, unavailable }

/// Thin wrapper around `speech_to_text`. It exposes exactly what the state
/// machine needs and nothing else:
///   * permission/availability handling
///   * a normalised 0..1 sound-level stream (drives the orb while listening)
///   * partial + final transcript callbacks
///   * graceful "no speech detected" / error reporting
///
/// The controller gates this against TTS so the mic is never open while the
/// student is talking (no feedback loop).
class SpeechService {
  final SpeechToText _stt = SpeechToText();

  bool _initialized = false;

  // Live callbacks for the current listen session.
  void Function(String text, bool isFinal)? _onResult;
  void Function(double level)? _onLevel;
  void Function(String message, {bool noSpeech})? _onError;
  void Function()? _onDone;

  bool get isListening => _stt.isListening;

  Future<SpeechAvailability> ensureInitialized() async {
    if (_initialized && _stt.isAvailable) return SpeechAvailability.ready;
    try {
      final available = await _stt.initialize(
        onError: _handleError,
        onStatus: _handleStatus,
        // `speech_to_text` requests the OS mic/recognition permission here.
      );
      _initialized = true;
      if (!available) return SpeechAvailability.denied;
      return SpeechAvailability.ready;
    } catch (_) {
      return SpeechAvailability.unavailable;
    }
  }

  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    required void Function(double level) onLevel,
    required void Function(String message, {bool noSpeech}) onError,
    required void Function() onDone,
  }) async {
    _onResult = onResult;
    _onLevel = onLevel;
    _onError = onError;
    _onDone = onDone;

    await _stt.listen(
      onResult: _handleResult,
      onSoundLevelChange: _handleLevel,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation, // long-form explanations
        // Generous windows — people pause while explaining.
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 4),
      ),
    );
  }

  /// Stop and keep the final result. Used when the learner taps "done".
  Future<void> stop() async {
    if (_stt.isListening) await _stt.stop();
  }

  /// Abort without finalising. Used when the session is torn down.
  Future<void> cancel() async {
    if (_stt.isListening) await _stt.cancel();
  }

  void _handleResult(SpeechRecognitionResult result) {
    _onResult?.call(result.recognizedWords, result.finalResult);
  }

  void _handleLevel(double level) {
    // iOS reports roughly [-2, 10]; Android reports dB-ish positive values.
    // Map onto 0..1 with a soft curve; the orb smooths further.
    final normalized = ((level + 2) / 12).clamp(0.0, 1.0);
    _onLevel?.call(normalized);
  }

  void _handleError(SpeechRecognitionError error) {
    final noSpeech =
        error.errorMsg.contains('no_match') || error.errorMsg.contains('speech_timeout');
    if (noSpeech) {
      _onError?.call("I didn't catch that — nothing was picked up.", noSpeech: true);
    } else {
      _onError?.call('Speech recognition error: ${error.errorMsg}', noSpeech: false);
    }
  }

  void _handleStatus(String status) {
    // Fired when the recognizer stops on its own (pause window elapsed, etc.).
    if (status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) {
      _onDone?.call();
    }
  }
}
