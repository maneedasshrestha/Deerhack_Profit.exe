import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'shell/main_shell.dart';

class FeynmanApp extends ConsumerWidget {
  const FeynmanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
    ));
    return MaterialApp(
      title: 'ACELY',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // The app is intentionally light-only: one calm, consistent look.
      themeMode: ThemeMode.light,
      home: const MainShell(initialIndex: 0),
    );
  }
}
