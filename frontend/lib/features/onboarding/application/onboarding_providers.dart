import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile_repository.dart';
import '../domain/user_profile.dart';

/// Injected at startup in main.dart (same pattern as sessionRepositoryProvider).
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  throw UnimplementedError('profileRepositoryProvider must be overridden');
});

/// The active profile, or null while the learner is still onboarding. The app
/// shell watches this: null → onboarding flow, set → the main app.
class UserProfileNotifier extends StateNotifier<UserProfile?> {
  UserProfileNotifier(this._repo) : super(_repo.get());

  final ProfileRepository _repo;

  /// Persist a freshly built profile and flip the app into its main shell.
  Future<void> complete(UserProfile profile) async {
    await _repo.save(profile);
    state = profile;
  }

  /// Clear the profile and return to onboarding (used by "restart onboarding").
  Future<void> reset() async {
    await _repo.clear();
    state = null;
  }
}

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile?>(
        (ref) => UserProfileNotifier(ref.watch(profileRepositoryProvider)));
