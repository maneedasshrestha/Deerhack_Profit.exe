import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/weekly_mock_repository.dart';
import '../domain/ioe_exam.dart';

/// The weekly-mock data source. Defaults to the offline fallback; main.dart
/// overrides it with the Supabase-backed repository when the project is wired
/// up (same pattern as the auth / profile-sync providers).
final weeklyMockRepositoryProvider = Provider<WeeklyMockRepository>(
  (ref) => const OfflineWeeklyMockRepository(),
);

/// Loads the mock paper for a given week. The screen watches this and renders
/// loading / error / ready states off it — `family` so each week's paper is
/// fetched (and cached) independently.
final weeklyMockExamProvider =
    FutureProvider.family<WeeklyMockExam, int>((ref, weekNumber) {
  final repo = ref.watch(weeklyMockRepositoryProvider);
  return repo.loadExam(weekNumber: weekNumber);
});
