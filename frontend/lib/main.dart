import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'features/feynman/application/providers.dart';
import 'features/feynman/data/repository/session_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local persistence — open the sessions box before the app reads it.
  await Hive.initFlutter();
  final repository = await HiveSessionRepository.open();

  // The app reads better in dark, but both orientations are supported.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(
    ProviderScope(
      overrides: [
        // Inject the opened repository. Flip useMockEngine to false (and set a
        // real proxyBaseUrl) in appConfigProvider to hit the live backend.
        sessionRepositoryProvider.overrideWithValue(repository),
      ],
      child: const FeynmanApp(),
    ),
  );
}
