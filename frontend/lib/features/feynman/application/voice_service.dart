import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

/// Wraps `flutter_tts` to give the student a *character* voice — slightly higher
/// pitch and slightly slower rate so it reads as a curious kid, not a robot.
///
/// [speak] resolves only when playback actually finishes, which lets the state
/// machine guarantee the mic stays closed for the whole time the student talks.
class VoiceService {
  final FlutterTts _tts = FlutterTts();
  bool _configured = false;
  Completer<void>? _speaking;

  Future<void> _configure() async {
    if (_configured) return;
    await _tts.setLanguage('en-US');
    await _tts.setPitch(1.25); // higher → reads as a child
    await _tts.setSpeechRate(0.42); // slower → unhurried, characterful
    await _tts.setVolume(1.0);
    // Make speak() awaitable to completion on both platforms.
    await _tts.awaitSpeakCompletion(true);

    _tts.setCompletionHandler(() => _finish());
    _tts.setCancelHandler(() => _finish());
    _tts.setErrorHandler((_) => _finish());

    _configured = true;
  }

  void _finish() {
    if (_speaking != null && !_speaking!.isCompleted) {
      _speaking!.complete();
    }
  }

  /// Speak [text] and resolve when it has finished (or errored/cancelled).
  Future<void> speak(String text) async {
    await _configure();
    if (text.trim().isEmpty) return;

    await stop(); // never overlap utterances
    _speaking = Completer<void>();
    await _tts.speak(text);
    // awaitSpeakCompletion makes the above await until done on most engines;
    // the completer is a belt-and-suspenders guard for engines that don't.
    await _speaking!.future;
  }

  Future<void> stop() async {
    await _tts.stop();
    _finish();
  }
}
