import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app.dart';
import 'package:frontend/features/feynman/application/providers.dart';
import 'package:frontend/features/feynman/data/repository/session_repository.dart';
import 'package:frontend/features/feynman/domain/models/feynman_session.dart';
import 'package:frontend/features/onboarding/application/onboarding_providers.dart';
import 'package:frontend/features/onboarding/application/plan_providers.dart';
import 'package:frontend/features/onboarding/data/plan_repository.dart';
import 'package:frontend/features/onboarding/data/profile_repository.dart';
import 'package:frontend/features/onboarding/domain/curated_plan.dart';
import 'package:frontend/features/onboarding/domain/user_profile.dart';

class _FakeProfileRepo implements ProfileRepository {
  _FakeProfileRepo(this._p);
  UserProfile? _p;
  @override
  UserProfile? get() => _p;
  @override
  Future<void> save(UserProfile profile) async => _p = profile;
  @override
  Future<void> clear() async => _p = null;
}

class _FakePlanRepo implements PlanRepository {
  _FakePlanRepo(this._p);
  CuratedPlan? _p;
  @override
  CuratedPlan? get() => _p;
  @override
  Future<void> save(CuratedPlan plan) async => _p = plan;
  @override
  Future<void> clear() async => _p = null;
}

class _FakeSessionRepo implements SessionRepository {
  @override
  Future<void> save(FeynmanSession session) async {}
  @override
  List<FeynmanSession> versionsOf(String conceptId) => const [];
  @override
  List<FeynmanSession> latestPerConcept() => const [];
  @override
  int nextVersion(String conceptId) => 1;
  @override
  String? conceptIdForName(String name) => null;
  @override
  FeynmanSession? byId(String id) => null;
}

UserProfile _profile() => UserProfile(
      fullName: 'Test User',
      email: 't@e.com',
      examId: 'ioe',
      examName: 'IOE Entrance',
      examDate: DateTime(2030, 1, 1),
      targetMarks: 60,
      totalMarks: 100,
      dailyHours: 2,
      createdAt: DateTime(2026, 1, 1),
    );

CuratedPlan _plan() => CuratedPlan(
      summary: 's',
      totalWeeks: 4,
      weeklyHours: 14,
      focusAreas: const ['a'],
      subjectFocus: const [],
      milestones: const [],
      generatedAt: DateTime(2026, 1, 1),
    );

void main() {
  testWidgets('typing an explanation to the Feynman tutor does not crash',
      (tester) async {
    tester.view.physicalSize = const Size(400, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(proxyBaseUrl: 'http://x', useMockEngine: true),
          ),
          profileRepositoryProvider
              .overrideWithValue(_FakeProfileRepo(_profile())),
          planRepositoryProvider.overrideWithValue(_FakePlanRepo(_plan())),
          sessionRepositoryProvider.overrideWithValue(_FakeSessionRepo()),
        ],
        child: const FeynmanApp(),
      ),
    );

    await tester.pump();

    // Coach tab -> type a concept -> Start session.
    await tester.tap(find.bySemanticsLabel('Coach'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField).first, 'gravity');
    await tester.pump();
    await tester.tap(find.text('Start session'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }

    // Open the "type instead" sheet and submit an explanation.
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.enterText(
        find.byType(TextField).first, 'gravity pulls things down');
    await tester.pump();
    await tester.tap(find.text('Send to coach'));
    // Drive the phase transitions (sheet close, transcript update, thinking).
    // We do NOT pumpAndSettle: the orb animates forever and TTS never completes
    // in a test. Pump past the mock engine's ~1.1s simulated latency so its
    // timer fires and isn't left pending at teardown.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.pump(const Duration(milliseconds: 1300));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }

    expect(tester.takeException(), isNull);
  });
}
