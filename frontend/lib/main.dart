import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'features/feynman/application/providers.dart';
import 'features/feynman/data/repository/session_repository.dart';
import 'features/onboarding/application/onboarding_providers.dart';
import 'features/onboarding/application/plan_providers.dart';
import 'features/onboarding/data/plan_repository.dart';
import 'features/onboarding/data/profile_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local persistence — open the boxes before the app reads them.
  await Hive.initFlutter();
  final repository = await HiveSessionRepository.open();
  final profileRepository = await HiveProfileRepository.open();
  final planRepository = await HivePlanRepository.open();

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
        // proxyBaseUrl if needed) in appConfigProvider to hit the live backend.
        sessionRepositoryProvider.overrideWithValue(repository),
        // The onboarding profile gates the app between the signup flow and the
        // main shell. The curated plan gates the loading step in between.
        profileRepositoryProvider.overrideWithValue(profileRepository),
        planRepositoryProvider.overrideWithValue(planRepository),
      ],
      child: const FeynmanApp(),
    ),
  );
}
