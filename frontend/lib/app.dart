import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'shell/main_shell.dart';

/// App-wide theme mode. Dark is the designed-first default.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

class FeynmanApp extends ConsumerWidget {
  const FeynmanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'ACELY',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      // Start on the Learn tab (index 1) — the Duolingo-style home screen.
      home: const MainShell(initialIndex: 1),
    );
  }
}
