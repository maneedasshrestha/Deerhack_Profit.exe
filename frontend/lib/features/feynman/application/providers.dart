import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/engine/mock_student_engine.dart';
import '../data/engine/turn_based_student_engine.dart';
import '../data/repository/session_repository.dart';
import '../domain/student_engine.dart';
import '../domain/models/feynman_state.dart';
import 'feynman_controller.dart';
import 'session_args.dart';
import 'speech_service.dart';
import 'voice_service.dart';

/// Runtime configuration for the engine.
class AppConfig {
  const AppConfig({required this.proxyBaseUrl, required this.useMockEngine});

  /// Base URL of the backend proxy.
  ///   * Android emulator → http://10.0.2.2:8787
  ///   * iOS simulator / desktop → http://localhost:8787
  final String proxyBaseUrl;

  /// When true, use the offline [MockStudentEngine] so the app runs end-to-end
  /// with no backend. Flip to false to hit the real proxy.
  final bool useMockEngine;
}

/// Override in `main()` if you point at a real proxy. Defaults to mock so the
/// app is runnable out of the box.
final appConfigProvider = Provider<AppConfig>(
  (ref) => const AppConfig(
    // Android emulator reaches the host machine at 10.0.2.2.
    // iOS simulator / desktop: use http://localhost:8787.
    proxyBaseUrl: 'http://10.0.2.2:8787',
    // Running fully offline against the heuristic MockStudentEngine and the
    // local MockPlanService (no backend needed). Set to false to hit the proxy.
    useMockEngine: true,
  ),
);

/// Provided via override in `main()` after Hive is open.
final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) =>
      throw UnimplementedError('sessionRepositoryProvider must be overridden'),
);

final studentEngineProvider = Provider<StudentEngine>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockEngine) return MockStudentEngine();
  final engine = TurnBasedStudentEngine(baseUrl: config.proxyBaseUrl);
  ref.onDispose(engine.dispose);
  return engine;
});

final speechServiceProvider = Provider<SpeechService>((ref) => SpeechService());
final voiceServiceProvider = Provider<VoiceService>((ref) => VoiceService());

/// The live session state machine, keyed by which concept/version is being
/// taught. autoDispose tears down STT/TTS when the live screen is popped.
final feynmanControllerProvider = StateNotifierProvider.autoDispose
    .family<FeynmanController, FeynmanState, SessionArgs>((ref, args) {
      final controller = FeynmanController(
        args: args,
        engine: ref.watch(studentEngineProvider),
        speech: ref.watch(speechServiceProvider),
        voice: ref.watch(voiceServiceProvider),
        repository: ref.watch(sessionRepositoryProvider),
      );
      ref.onDispose(controller.disposeServices);
      return controller;
    });
