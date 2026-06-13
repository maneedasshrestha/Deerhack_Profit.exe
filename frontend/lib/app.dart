import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/onboarding/application/onboarding_providers.dart';
import 'features/onboarding/application/plan_providers.dart';
import 'features/onboarding/presentation/screens/onboarding_flow_screen.dart';
import 'features/onboarding/presentation/screens/plan_generation_screen.dart';
import 'shell/main_shell.dart';

class FeynmanApp extends ConsumerWidget {
  const FeynmanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
    ));
    // Three-way entry gate:
    //   no profile          → onboarding signup
    //   profile, no plan     → loading screen builds the curated plan
    //   profile + plan       → the main app
    final hasProfile = ref.watch(userProfileProvider) != null;
    final hasPlan = ref.watch(curatedPlanProvider) != null;
    final Widget home;
    if (!hasProfile) {
      home = const OnboardingFlowScreen();
    } else if (!hasPlan) {
      home = const PlanGenerationScreen();
    } else {
      home = const MainShell(initialIndex: 0);
    }
    return MaterialApp(
      title: 'नित्यम्',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // The app is intentionally light-only: one calm, consistent look.
      themeMode: ThemeMode.light,
      home: home,
    );
  }
}
