import '../domain/auth_account.dart';

// ═══════════════════════════════════════════════════════════════════════════
// AuthService — the single seam between onboarding and whatever identity
// provider backs the app. The UI only ever talks to this interface.
//
// Today [MockGoogleAuthService] returns a canned account after a short delay so
// the whole sign-in → onboarding flow is exercisable with no backend, no OAuth
// config, and no extra packages. When the Supabase project is ready, implement
// this same interface with the real Google / Supabase calls and override
// `authServiceProvider` (see application/auth_providers.dart) — nothing in the
// presentation layer has to change.
// ═══════════════════════════════════════════════════════════════════════════
abstract class AuthService {
  /// Begins the Google sign-in handshake. Returns the signed-in account, or
  /// null if the user dismissed the consent sheet.
  Future<AuthAccount?> signInWithGoogle();

  /// Ends the session (clears any provider tokens). No-op for the mock.
  Future<void> signOut();
}

/// Stand-in until real auth is wired. Pretends to round-trip the Google consent
/// sheet, then hands back a fixed account.
class MockGoogleAuthService implements AuthService {
  const MockGoogleAuthService();

  @override
  Future<AuthAccount?> signInWithGoogle() async {
    // Simulate the consent-sheet round trip so the button's loading state and
    // the screen transition feel real.
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    return const AuthAccount(
      id: 'mock-google-uid',
      name: 'Aarav Sharma',
      email: 'aarav.sharma@gmail.com',
      // No provider photo on purpose → onboarding's photo step offers an upload
      // and shows the gradient-initials default until one is chosen.
      photoUrl: null,
    );
  }

  @override
  Future<void> signOut() async {
    // Nothing to tear down for the mock.
  }
}
