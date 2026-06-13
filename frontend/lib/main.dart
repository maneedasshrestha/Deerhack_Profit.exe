import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'features/feynman/application/providers.dart';
import 'features/feynman/data/repository/session_repository.dart';
import 'features/onboarding/application/auth_providers.dart';
import 'features/onboarding/application/onboarding_providers.dart';
import 'features/onboarding/application/plan_providers.dart';
import 'features/onboarding/data/plan_repository.dart';
import 'features/onboarding/data/profile_repository.dart';
import 'features/onboarding/data/profile_sync_service.dart';
import 'features/onboarding/data/supabase_auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local persistence — open the boxes before the app reads them.
  await Hive.initFlutter();
  final repository = await HiveSessionRepository.open();
  final profileRepository = await HiveProfileRepository.open();
  final planRepository = await HivePlanRepository.open();

  // Real auth/database — only when the project is wired up (--dart-define).
  // Without it the app falls back to the mock auth service and stays local.
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      // The dashboard's "anon/public" key. (supabase_flutter 2.x still accepts
      // it; `publishableKey` is the newer alias for the same client-safe key.)
      // ignore: deprecated_member_use
      anonKey: SupabaseConfig.anonKey,
    );
  }

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
        // Wire real auth + cloud profile sync when Supabase is configured;
        // otherwise the providers keep their mock/no-op defaults.
        if (SupabaseConfig.isConfigured) ...[
          authServiceProvider.overrideWithValue(
            SupabaseAuthService(
              webClientId: SupabaseConfig.googleWebClientId,
              iosClientId: SupabaseConfig.googleIosClientId,
            ),
          ),
          profileSyncProvider
              .overrideWithValue(const SupabaseProfileSyncService()),
        ],
      ],
      child: const FeynmanApp(),
    ),
  );
}
