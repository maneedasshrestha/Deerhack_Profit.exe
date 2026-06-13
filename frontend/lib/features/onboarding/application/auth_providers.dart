import 'package:flutter_riverpod/flutter_riverpod.dart';

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
