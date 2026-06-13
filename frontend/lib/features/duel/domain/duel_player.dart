import 'package:flutter/foundation.dart';

// ═══════════════════════════════════════════════════════════════════════════
// DuelPlayer — a registered duellist. Every app instance self-registers one of
// these (a stable local UUID + display name) so challenges, the friends list
// and the leaderboard resolve to real rows instead of hardcoded mock data.
// ═══════════════════════════════════════════════════════════════════════════
@immutable
class DuelPlayer {
  const DuelPlayer({
    required this.id,
    required this.displayName,
    required this.initials,
    this.photoUrl,
    this.updatedAt,
  });

  final String id;
  final String displayName;
  final String initials;

  /// A shareable (network) avatar URL for this player, or null → fall back to
  /// the gradient-initials avatar. Local file paths are intentionally not
  /// stored here: they're meaningless on another device.
  final String? photoUrl;

  /// Last time this player's row was touched. Used as an "online now" heuristic.
  final DateTime? updatedAt;

  /// Treat a player seen within the last few minutes as online.
  bool get isOnline {
    final at = updatedAt;
    if (at == null) return false;
    return DateTime.now().toUtc().difference(at.toUtc()).inMinutes < 5;
  }

  static String initialsFor(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.map((w) => w[0].toUpperCase()).take(2).join();
  }

  factory DuelPlayer.fromJson(Map<String, dynamic> json) => DuelPlayer(
        id: json['id'] as String,
        displayName: json['display_name'] as String? ?? 'Player',
        initials: json['initials'] as String? ??
            initialsFor(json['display_name'] as String? ?? '?'),
        photoUrl: json['photo_url'] as String?,
        updatedAt: json['updated_at'] == null
            ? null
            : DateTime.tryParse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': displayName,
        'initials': initials,
        'photo_url': photoUrl,
      };
}
