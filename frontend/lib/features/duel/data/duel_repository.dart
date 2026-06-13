import '../domain/duel_invite.dart';
import '../domain/duel_leaderboard_entry.dart';
import '../domain/duel_match.dart';
import '../domain/duel_player.dart';

/// Aggregate duel record for a player.
class DuelStats {
  const DuelStats({this.wins = 0, this.losses = 0, this.played = 0});

  final int wins;
  final int losses;
  final int played;

  int get winRate {
    final decided = wins + losses;
    return decided == 0 ? 0 : (wins * 100) ~/ decided;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DuelRepository — the data boundary for async duels. The challenger creates a
// duel (having just played); the opponent loads it by code and submits their
// result, at which point the winner is computed. Stats / history / players are
// all derived from the persisted duels and player rows.
//
// The default [InMemoryDuelRepository] keeps everything in process — used when
// Supabase isn't configured so the app still runs (single-device only).
// ═══════════════════════════════════════════════════════════════════════════
abstract class DuelRepository {
  /// Register / refresh the local player's row (self-registration + heartbeat).
  Future<void> registerSelf(DuelPlayer me);

  /// Persist a new duel after the challenger has played. [targetOpponent], when
  /// set, makes it a targeted challenge (shows up in that player's inbox);
  /// otherwise it's an open challenge anyone can pick up by code or quick-match.
  Future<DuelMatch> createDuel({
    required DuelPlayer challenger,
    required String topic,
    required List<String> questionIds,
    required List<bool> challengerAnswers,
    required int challengerScore,
    DuelPlayer? targetOpponent,
  });

  /// Look up a duel by its short code (QR / manual entry). Code is normalised.
  Future<DuelMatch?> getDuelByCode(String code);

  /// Opponent submits their result; returns the completed duel (winner set).
  Future<DuelMatch> submitOpponentResult({
    required String duelId,
    required DuelPlayer opponent,
    required int opponentScore,
  });

  Future<DuelStats> fetchStats(String playerId);

  /// Completed duels involving [playerId], most recent first.
  Future<List<DuelMatch>> fetchHistory(String playerId);

  /// Other registered players, most recently seen first.
  Future<List<DuelPlayer>> fetchPlayers(String excludeId);

  /// Targeted challenges addressed to [playerId] still awaiting their play.
  Future<List<DuelMatch>> fetchIncomingChallenges(String playerId);

  /// An open challenge from the pool to quick-match into, or null if none.
  Future<DuelMatch?> findOpenChallenge(String excludeId);

  /// Registered players ranked by wins (then duels played), top [limit] first.
  Future<List<DuelLeaderboardEntry>> fetchLeaderboard({int limit = 20});
}

/// Compute the winner id of a finished duel (null = draw).
String? duelWinnerId(DuelMatch d, String opponentId, int opponentScore) {
  final mine = d.challengerScore ?? 0;
  if (opponentScore > mine) return opponentId;
  if (opponentScore < mine) return d.challengerId;
  return null;
}

// ─── In-memory fallback (no Supabase) ─────────────────────────────────────────
class InMemoryDuelRepository implements DuelRepository {
  final Map<String, DuelPlayer> _players = {};
  final Map<String, DuelMatch> _duels = {}; // by id
  int _seq = 0;

  @override
  Future<void> registerSelf(DuelPlayer me) async {
    _players[me.id] = DuelPlayer(
      id: me.id,
      displayName: me.displayName,
      initials: me.initials,
      photoUrl: me.photoUrl,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<DuelMatch> createDuel({
    required DuelPlayer challenger,
    required String topic,
    required List<String> questionIds,
    required List<bool> challengerAnswers,
    required int challengerScore,
    DuelPlayer? targetOpponent,
  }) async {
    final id = 'local-${_seq++}';
    final duel = DuelMatch(
      id: id,
      code: DuelInvite.normalize(DuelInvite.newCode()),
      topic: topic,
      questionIds: questionIds,
      challengerId: challenger.id,
      challengerName: challenger.displayName,
      challengerPhotoUrl: challenger.photoUrl,
      challengerAnswers: challengerAnswers,
      challengerScore: challengerScore,
      challengerFinishedAt: DateTime.now().toUtc(),
      opponentId: targetOpponent?.id,
      opponentName: targetOpponent?.displayName,
      opponentPhotoUrl: targetOpponent?.photoUrl,
      createdAt: DateTime.now().toUtc(),
    );
    _duels[id] = duel;
    return duel;
  }

  @override
  Future<DuelMatch?> getDuelByCode(String code) async {
    final norm = DuelInvite.normalize(code);
    for (final d in _duels.values) {
      if (d.code == norm) return d;
    }
    return null;
  }

  @override
  Future<DuelMatch> submitOpponentResult({
    required String duelId,
    required DuelPlayer opponent,
    required int opponentScore,
  }) async {
    final d = _duels[duelId]!;
    final withOpp = d.copyWith(
      opponentId: opponent.id,
      opponentName: opponent.displayName,
      opponentPhotoUrl: opponent.photoUrl,
      opponentScore: opponentScore,
      opponentFinishedAt: DateTime.now().toUtc(),
      winnerId: duelWinnerId(d, opponent.id, opponentScore),
      status: DuelStatus.completed,
    );
    _duels[duelId] = withOpp;
    return withOpp;
  }

  @override
  Future<DuelStats> fetchStats(String playerId) async {
    var wins = 0, losses = 0, played = 0;
    for (final d in _duels.values) {
      if (!d.isCompleted) continue;
      if (d.challengerId != playerId && d.opponentId != playerId) continue;
      played++;
      if (d.winnerId == playerId) {
        wins++;
      } else if (d.winnerId != null) {
        losses++;
      }
    }
    return DuelStats(wins: wins, losses: losses, played: played);
  }

  @override
  Future<List<DuelMatch>> fetchHistory(String playerId) async {
    final out = _duels.values
        .where((d) =>
            d.isCompleted &&
            (d.challengerId == playerId || d.opponentId == playerId))
        .toList()
      ..sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return out;
  }

  @override
  Future<List<DuelPlayer>> fetchPlayers(String excludeId) async =>
      _players.values.where((p) => p.id != excludeId).toList();

  @override
  Future<List<DuelMatch>> fetchIncomingChallenges(String playerId) async =>
      _duels.values
          .where((d) =>
              d.status == DuelStatus.awaitingOpponent &&
              d.opponentId == playerId)
          .toList();

  @override
  Future<DuelMatch?> findOpenChallenge(String excludeId) async {
    for (final d in _duels.values) {
      if (d.status == DuelStatus.awaitingOpponent &&
          d.opponentId == null &&
          d.challengerId != excludeId) {
        return d;
      }
    }
    return null;
  }

  @override
  Future<List<DuelLeaderboardEntry>> fetchLeaderboard({int limit = 20}) async {
    final entries = <DuelLeaderboardEntry>[];
    for (final p in _players.values) {
      var wins = 0, losses = 0, played = 0;
      for (final d in _duels.values) {
        if (!d.isCompleted) continue;
        if (d.challengerId != p.id && d.opponentId != p.id) continue;
        played++;
        if (d.winnerId == p.id) {
          wins++;
        } else if (d.winnerId != null) {
          losses++;
        }
      }
      entries.add(DuelLeaderboardEntry(
        id: p.id,
        displayName: p.displayName,
        initials: p.initials,
        played: played,
        wins: wins,
        losses: losses,
        photoUrl: p.photoUrl,
      ));
    }
    entries.sort((a, b) {
      final byWins = b.wins.compareTo(a.wins);
      return byWins != 0 ? byWins : b.played.compareTo(a.played);
    });
    return entries.take(limit).toList();
  }
}
