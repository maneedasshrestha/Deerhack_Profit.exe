import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/duel/presentation/screens/duel_screen.dart';
import '../features/feynman/presentation/screens/concept_setup_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';

/// Three-tab root shell:
///   0 — Learn tab  (weekly Duolingo-style plan)
///   1 — Coach tab  (Feynman coach)
///   2 — Duel tab   (real-time versus lobby)
///
/// IndexedStack keeps every tab alive across switches so state (scroll
/// position, in-progress lesson) is preserved. Each tab owns its own
/// Navigator so internal pushes stay within the tab and the bottom nav
/// remains visible.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index;

  // One navigatorKey per tab — needed for per-tab back-navigation.
  final _keys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  // Handle Android back button: pop within the current tab first.
  Future<bool> _onWillPop() async {
    final nav = _keys[_index].currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final handled = !(await _onWillPop());
          if (!handled && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            _Tab(navigatorKey: _keys[0], child: const HomeScreen()),
            _Tab(navigatorKey: _keys[1], child: const ConceptSetupScreen()),
            _Tab(navigatorKey: _keys[2], child: const DuelScreen()),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: p.surface,
          surfaceTintColor: Colors.transparent,
          indicatorColor: p.accentSoft,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map_rounded, color: p.accent),
              label: 'Learn',
            ),
            NavigationDestination(
              icon: const Icon(Icons.psychology_outlined),
              selectedIcon: Icon(Icons.psychology_rounded, color: p.accent),
              label: 'Coach',
            ),
            NavigationDestination(
              icon: const Icon(Icons.bolt_outlined),
              selectedIcon: Icon(Icons.bolt_rounded, color: p.accent),
              label: 'Duel',
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps a root widget in its own Navigator so each tab can push/pop
/// independently without touching the shell's route stack.
class _Tab extends StatelessWidget {
  const _Tab({required this.navigatorKey, required this.child});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => child),
    );
  }
}
