/// Supabase + Google sign-in configuration, supplied at build time so no secrets
/// are committed. Pass them with --dart-define (or --dart-define-from-file):
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJhbGci... \
///     --dart-define=GOOGLE_WEB_CLIENT_ID=1234-abc.apps.googleusercontent.com
///
/// All three values are publishable (the anon key and OAuth *client* IDs are
/// designed to ship in client apps), so committing them in a dart-define file is
/// fine too. When [isConfigured] is false the app falls back to the mock auth
/// service, so it still runs with no backend.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// The OAuth **Web** client ID. On Android this is passed to google_sign_in as
  /// `serverClientId`; it is also the audience Supabase expects on the ID token.
  static const String googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  /// The OAuth **iOS** client ID. Required for native Google sign-in on iOS:
  /// google_sign_in passes it as `clientId`, and its reversed form must be
  /// registered as a URL scheme in ios/Runner/Info.plist. Leave empty on
  /// platforms that don't need it (e.g. Android).
  static const String googleIosClientId =
      String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  /// True once the Supabase project is wired up. Gates real auth vs the mock.
  static bool get isConfigured =>
      url.isNotEmpty && anonKey.isNotEmpty && googleWebClientId.isNotEmpty;
}
