import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_service.dart';

/// The identity provider behind sign-in. Defaults to the mock so the flow works
/// out of the box; override in main.dart (or a test) to plug in real
/// Google / Supabase auth once the backend exists — no UI changes required.
final authServiceProvider =
    Provider<AuthService>((ref) => const MockGoogleAuthService());
