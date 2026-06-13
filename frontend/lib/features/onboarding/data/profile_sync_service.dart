import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/user_profile.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ProfileSyncService — pushes a freshly built profile to the cloud at the end of
// onboarding: uploads the chosen photo to Supabase Storage and upserts the row
// in the `profiles` table. Returns the profile with its photoPath rewritten to
// the public Storage URL (so it survives reinstalls and shows on any device).
//
// The default [NoopProfileSyncService] does nothing — used when Supabase isn't
// configured, so the app stays local-only and never blocks on a network call.
// ═══════════════════════════════════════════════════════════════════════════
abstract class ProfileSyncService {
  /// Persist [profile] for the signed-in [userId]. May return an updated copy
  /// (e.g. with a remote photo URL). Throws on network/permission failure.
  Future<UserProfile> persist(UserProfile profile, {required String userId});
}

/// Local-only stand-in: returns the profile untouched.
class NoopProfileSyncService implements ProfileSyncService {
  const NoopProfileSyncService();

  @override
  Future<UserProfile> persist(UserProfile profile, {required String userId}) async =>
      profile;
}

class SupabaseProfileSyncService implements ProfileSyncService {
  const SupabaseProfileSyncService();

  static const String _bucket = 'avatars';
  static const String _table = 'profiles';

  SupabaseClient get _sb => Supabase.instance.client;

  @override
  Future<UserProfile> persist(UserProfile profile,
      {required String userId}) async {
    // Avatar upload is best-effort: there is no column to store the URL yet, and
    // a missing/unconfigured bucket must never block the onboarding row.
    var synced = profile;
    try {
      final photoUrl = await _uploadPhotoIfLocal(profile.photoPath, userId);
      synced = profile.copyWith(photoPath: photoUrl);
    } catch (_) {
      // Keep the local path; carry on writing the profile row.
    }

    // Mapped onto the real `profiles` schema. The table stores the exam label in
    // `exam_type`, study time as `daily_minutes`, and a `date` (not timestamp)
    // for `exam_date`.
    await _sb.from(_table).upsert({
      'id': userId,
      'full_name': synced.fullName,
      'email': synced.email,
      'exam_type': synced.examName,
      'exam_date': _dateOnly(synced.examDate),
      'target_marks': synced.targetMarks,
      'daily_minutes': (synced.dailyHours * 60).round(),
      'onboarded_at': DateTime.now().toUtc().toIso8601String(),
    });

    return synced;
  }

  /// `exam_date` is a SQL `date` column — send `YYYY-MM-DD`, not a timestamp.
  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Uploads a local file path to Storage and returns its public URL. Leaves
  /// existing URLs (already-remote) and missing files alone.
  Future<String?> _uploadPhotoIfLocal(String? path, String userId) async {
    if (path == null || path.isEmpty) return path;
    if (path.startsWith('http')) return path; // already a remote URL
    final file = File(path);
    if (!file.existsSync()) return null;

    // One object per user, overwritten on re-onboarding.
    final objectPath = '$userId/avatar.jpg';
    await _sb.storage.from(_bucket).upload(
          objectPath,
          file,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
    return _sb.storage.from(_bucket).getPublicUrl(objectPath);
  }
}
