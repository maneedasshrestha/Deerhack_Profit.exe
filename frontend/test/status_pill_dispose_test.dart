import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/feynman/presentation/widgets/status_pill.dart';

// Regression test for the lazy `late final` AnimationController in StatusPill.
//
// The pill's pulse controller used to be a lazy field initializer that was only
// accessed while `recording` was true. When a pill mounted idle (recording:
// false) and was then removed, the FIRST access to the controller was
// `_pulse.dispose()` inside dispose() — which constructed the controller on an
// already-deactivated element and crashed (TickerMode lookup on a defunct
// widget; surfaces as "deactivated ancestor" or InheritedElement
// `_dependents.isEmpty`). It must now dispose cleanly.
void main() {
  testWidgets('StatusPill that never records disposes without crashing',
      (tester) async {
    Widget host(bool show) => MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: show
                  ? const StatusPill(
                      concept: 'gravity', version: 1, recording: false)
                  : const SizedBox.shrink(),
            ),
          ),
        );

    await tester.pumpWidget(host(true));
    expect(find.byType(StatusPill), findsOneWidget);

    // Remove the pill — this triggers dispose() on a pill that never recorded.
    await tester.pumpWidget(host(false));
    await tester.pump();

    expect(find.byType(StatusPill), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
