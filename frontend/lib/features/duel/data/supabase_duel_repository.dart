import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/duel_invite.dart';
import '../domain/duel_match.dart';
import '../domain/duel_player.dart';
import 'duel_repository.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SupabaseDuelRepository — the live data layer for async duels, backed by the
// `duel_players` and `duels` tables (see supabase/migrations/0001_duel.sql).
// Used when Supabase is configured; otherwise the app falls back to the
// in-memory repository.
// ═══════════════════════════════════════════════════════════════════════════
class SupabaseDuelRepository implements DuelRepository {
  const SupabaseDuelRepository();

  static const _players = 'duel_players';
  static const _duels = 'duels';

  SupabaseClient get _sb => Supabase.instance.client;

  String _now() => DateTime.now().toUtc().toIso8601String();

  @override
  Future<void> registerSelf(DuelPlayer me) async {
    final row = {
      ...me.toJson(),
      'updated_at': _now(),
    };
    // Don't let a transient null (e.g. auth session not yet restored on app
    // open) wipe a previously-stored avatar. Only write photo_url when we have
    // one; omitted columns keep their existing value on upsert-conflict.
    if (me.photoUrl == null) row.remove('photo_url');
    await _sb.from(_players).upsert(row);
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
    final draft = DuelMatch(
      id: '', // assigned by the DB
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
    );
    final row = await _sb
        .from(_duels)
        .insert({
          ...draft.toInsertJson(),
          'updated_at': _now(),
        })
        .select()
        .single();
    return DuelMatch.fromJson(row);
  }

  @override
  Future<DuelMatch?> getDuelByCode(String code) async {
    final row = await _sb
        .from(_duels)
        .select()
        .eq('code', DuelInvite.normalize(code))
        .maybeSingle();
    return row == null ? null : DuelMatch.fromJson(row);
  }

  @override
  Future<DuelMatch> submitOpponentResult({
    required String duelId,
    required DuelPlayer opponent,
    required int opponentScore,
  }) async {
    final current = await _sb.from(_duels).select().eq('id', duelId).single();
    final duel = DuelMatch.fromJson(current);
    final winnerId = duelWinnerId(duel, opponent.id, opponentScore);

    final row = await _sb
        .from(_duels)
        .update({
          'opponent_id': opponent.id,
          'opponent_name': opponent.displayName,
          'opponent_photo_url': opponent.photoUrl,
          'opponent_score': opponentScore,
          'opponent_finished_at': _now(),
          'winner_id': winnerId,
          'status': 'completed',
          'updated_at': _now(),
        })
        .eq('id', duelId)
        .select()
        .single();
    return DuelMatch.fromJson(row);
  }

  @override
  Future<DuelStats> fetchStats(String playerId) async {
    final rows = await _sb
        .from(_duels)
        .select('challenger_id, opponent_id, winner_id, status')
        .or('challenger_id.eq.$playerId,opponent_id.eq.$playerId')
        .eq('status', 'completed');

    var wins = 0, losses = 0, played = 0;
    for (final r in rows as List) {
      played++;
      final winner = r['winner_id'] as String?;
      if (winner == playerId) {
        wins++;
      } else if (winner != null) {
        losses++;
      }
    }
    return DuelStats(wins: wins, losses: losses, played: played);
  }

  @override
  Future<List<DuelMatch>> fetchHistory(String playerId) async {
    final rows = await _sb
        .from(_duels)
        .select()
        .or('challenger_id.eq.$playerId,opponent_id.eq.$playerId')
        .eq('status', 'completed')
        .order('created_at', ascending: false)
        .limit(50);
    return [for (final r in rows as List) DuelMatch.fromJson(r)];
  }

  @override
  Future<List<DuelPlayer>> fetchPlayers(String excludeId) async {
    final rows = await _sb
        .from(_players)
        .select()
        .neq('id', excludeId)
        .order('updated_at', ascending: false)
        .limit(30);
    return [for (final r in rows as List) DuelPlayer.fromJson(r)];
  }

  @override
  Future<List<DuelMatch>> fetchIncomingChallenges(String playerId) async {
    final rows = await _sb
        .from(_duels)
        .select()
        .eq('opponent_id', playerId)
        .eq('status', 'awaiting_opponent')
        .order('created_at', ascending: false)
        .limit(20);
    return [for (final r in rows as List) DuelMatch.fromJson(r)];
  }

  @override
  Future<DuelMatch?> findOpenChallenge(String excludeId) async {
    final row = await _sb
        .from(_duels)
        .select()
        .eq('status', 'awaiting_opponent')
        .isFilter('opponent_id', null)
        .neq('challenger_id', excludeId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : DuelMatch.fromJson(row);
  }
}
