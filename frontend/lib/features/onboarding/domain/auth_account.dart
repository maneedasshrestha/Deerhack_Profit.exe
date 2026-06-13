import 'package:flutter/foundation.dart';

// ═══════════════════════════════════════════════════════════════════════════
// AuthAccount — the identity an external provider hands back after sign-in.
// Today it comes from a mock Google service; tomorrow from real Google / Supabase
// auth. The onboarding flow reads name + email (and an optional photo) from this
// to pre-fill the profile, so the learner never re-types what we already know.
// ═══════════════════════════════════════════════════════════════════════════
@immutable
class AuthAccount {
  const AuthAccount({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
  });

  /// Stable provider user id (Google sub / Supabase uid).
  final String id;
  final String name;
  final String email;

  /// Provider avatar URL, if the account has one. Null → onboarding offers an
  /// upload and falls back to a gradient-initials avatar.
  final String? photoUrl;

  /// First initials, e.g. "Aarav Sharma" → "AS". Falls back to "?".
  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.map((w) => w[0].toUpperCase()).take(2).join();
  }
}
