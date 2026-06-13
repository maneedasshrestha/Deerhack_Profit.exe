import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_service.dart';
import '../data/profile_sync_service.dart';

/// The identity provider behind sign-in. Defaults to the mock so the flow works
/// out of the box; main.dart overrides it with [SupabaseAuthService] when the
/// Supabase project is configured — no UI changes required.
final authServiceProvider =
    Provider<AuthService>((ref) => const MockGoogleAuthService());

/// Pushes the finished profile (row + avatar) to the cloud. Defaults to a no-op
/// (local-only); main.dart overrides it with [SupabaseProfileSyncService] when
/// Supabase is configured.
final profileSyncProvider =
    Provider<ProfileSyncService>((ref) => const NoopProfileSyncService());

/// The signed-in Google account's avatar URL, read from Supabase auth metadata
/// (`avatar_url`/`picture`). Used as the profile photo fallback when the learner
/// never uploaded one. Returns null when Supabase isn't configured / nobody is
/// signed in, so callers fall back to the gradient-initials avatar.
final signedInAvatarUrlProvider = Provider<String?>((ref) {
  try {
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata ?? const {};
    final url = meta['avatar_url'] ?? meta['picture'];
    return url is String && url.isNotEmpty ? url : null;
  } catch (_) {
    return null; // Supabase not initialised (mock mode).
  }
});
