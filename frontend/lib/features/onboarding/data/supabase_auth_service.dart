import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_account.dart';
import 'auth_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SupabaseAuthService — the real implementation of [AuthService].
//
// Flow (native, no browser bounce):
//   1. google_sign_in shows the in-app account picker and returns an ID token.
//   2. We hand that token to Supabase (signInWithIdToken) which creates/looks up
//      the auth.users row and a session (persisted by supabase_flutter).
//   3. We map the resulting user → AuthAccount for the onboarding flow.
//
// Pinned to google_sign_in 6.x on purpose: its signIn()/authentication API is
// the one the Supabase native-Google docs describe.
// ═══════════════════════════════════════════════════════════════════════════
class SupabaseAuthService implements AuthService {
  SupabaseAuthService({required String webClientId, String iosClientId = ''})
      : _google = GoogleSignIn(
          // iOS needs the *iOS* OAuth client ID. Its reversed form must also be
          // registered as a URL scheme in Info.plist, or signIn() fails. On
          // Android the client is matched by package name + SHA-1, so clientId
          // stays null there.
          clientId: iosClientId.isNotEmpty ? iosClientId : null,
          // The *server* (Web) client ID. On Android it's the only ID needed; it
          // is also the audience Supabase validates the ID token against.
          serverClientId: webClientId,
          scopes: const ['email', 'profile'],
        );

  final GoogleSignIn _google;

  SupabaseClient get _sb => Supabase.instance.client;

  @override
  Future<AuthAccount?> signInWithGoogle() async {
    // Returns null if the user dismisses the account picker.
    final googleUser = await _google.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;
    if (idToken == null) {
      throw const AuthException('Google did not return an ID token.');
    }

    final response = await _sb.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );

    final user = response.user;
    if (user == null) {
      throw const AuthException('Supabase did not return a user.');
    }

    final meta = user.userMetadata ?? const {};
    String? str(String key) => meta[key] as String?;

    return AuthAccount(
      id: user.id,
      name: str('full_name') ??
          str('name') ??
          googleUser.displayName ??
          (user.email?.split('@').first ?? 'there'),
      email: user.email ?? googleUser.email,
      photoUrl: str('avatar_url') ?? str('picture') ?? googleUser.photoUrl,
    );
  }

  @override
  Future<void> signOut() async {
    // Sign out of both so the next sign-in shows the account picker fresh.
    await _sb.auth.signOut();
    await _google.signOut();
  }
}
