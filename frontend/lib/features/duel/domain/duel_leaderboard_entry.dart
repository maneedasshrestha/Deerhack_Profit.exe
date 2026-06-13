import 'package:flutter/foundation.dart';

import 'duel_player.dart';

// ═══════════════════════════════════════════════════════════════════════════
// DuelLeaderboardEntry — one ranked row of the duel leaderboard. Backed by the
// `duel_leaderboard` view (see supabase/migrations/0001_duel.sql), which
// aggregates wins / losses / played per registered player.
// ═══════════════════════════════════════════════════════════════════════════
@immutable
class DuelLeaderboardEntry {
  const DuelLeaderboardEntry({
    required this.id,
    required this.displayName,
    required this.initials,
    required this.played,
    required this.wins,
    required this.losses,
    this.photoUrl,
  });

  final String id;
  final String displayName;
  final String initials;
  final int played;
  final int wins;
  final int losses;

  /// A shareable (network) avatar URL, or null → gradient-initials fallback.
  final String? photoUrl;

  /// Wins as a percentage of decided (non-draw) duels.
  int get winRate {
    final decided = wins + losses;
    return decided == 0 ? 0 : (wins * 100) ~/ decided;
  }

  factory DuelLeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      DuelLeaderboardEntry(
        id: json['id'] as String,
        displayName: json['display_name'] as String? ?? 'Player',
        initials: json['initials'] as String? ??
            DuelPlayer.initialsFor(json['display_name'] as String? ?? '?'),
        played: (json['played'] as num?)?.toInt() ?? 0,
        wins: (json['wins'] as num?)?.toInt() ?? 0,
        losses: (json['losses'] as num?)?.toInt() ?? 0,
        photoUrl: json['photo_url'] as String?,
      );
}
