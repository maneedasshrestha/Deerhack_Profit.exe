import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/domain/mock_data.dart';
import '../../onboarding/application/auth_providers.dart';
import '../../onboarding/application/onboarding_providers.dart';
import '../data/duel_identity.dart';
import '../data/duel_repository.dart';
import '../domain/duel_leaderboard_entry.dart';
import '../domain/duel_match.dart';
import '../domain/duel_player.dart';

/// The local player's stable id store. Injected at startup in main.dart (same
/// pattern as profileRepositoryProvider).
final duelIdentityProvider = Provider<DuelIdentity>((ref) {
  throw UnimplementedError('duelIdentityProvider must be overridden');
});

/// The duel data boundary. Defaults to the in-memory repository (single-device,
/// works offline); main.dart overrides it with [SupabaseDuelRepository] when
/// the Supabase project is configured.
final duelRepositoryProvider =
    Provider<DuelRepository>((ref) => InMemoryDuelRepository());

/// The local player (stable id + the name from their onboarding profile).
final currentPlayerProvider = Provider<DuelPlayer>((ref) {
  final identity = ref.watch(duelIdentityProvider);
  final profile = ref.watch(userProfileProvider);
  final name = profile?.fullName.trim().isNotEmpty == true
      ? profile!.fullName
      : MockData.userName;
  // Only a network URL is useful to other devices: prefer an uploaded photo
  // that's already a remote URL, else the signed-in Google avatar. A local
  // file path (the on-device uploaded photo) is skipped — it can't be shared.
  final uploaded = profile?.photoPath;
  final photoUrl = (uploaded != null && uploaded.startsWith('http'))
      ? uploaded
      : ref.watch(signedInAvatarUrlProvider);
  return identity.playerFor(name, photoUrl: photoUrl);
});

/// Win / loss / played totals for the local player.
final duelStatsProvider = FutureProvider<DuelStats>((ref) {
  final player = ref.watch(currentPlayerProvider);
  return ref.watch(duelRepositoryProvider).fetchStats(player.id);
});

/// Completed duels for the local player, most recent first.
final duelHistoryProvider = FutureProvider<List<DuelMatch>>((ref) {
  final player = ref.watch(currentPlayerProvider);
  return ref.watch(duelRepositoryProvider).fetchHistory(player.id);
});

/// Other registered players, most recently seen first.
final duelPlayersProvider = FutureProvider<List<DuelPlayer>>((ref) {
  final player = ref.watch(currentPlayerProvider);
  return ref.watch(duelRepositoryProvider).fetchPlayers(player.id);
});

/// Targeted challenges addressed to the local player and still awaiting play.
final incomingChallengesProvider = FutureProvider<List<DuelMatch>>((ref) {
  final player = ref.watch(currentPlayerProvider);
  return ref.watch(duelRepositoryProvider).fetchIncomingChallenges(player.id);
});

/// All registered duellists ranked by wins — backed by the leaderboard view.
final duelLeaderboardProvider =
    FutureProvider<List<DuelLeaderboardEntry>>((ref) {
  return ref.watch(duelRepositoryProvider).fetchLeaderboard();
});

/// Coordinates duel writes and refreshes the derived providers afterwards.
final duelControllerProvider = Provider<DuelController>((ref) {
  return DuelController(ref);
});

class DuelController {
  DuelController(this._ref);
  final Ref _ref;

  DuelRepository get _repo => _ref.read(duelRepositoryProvider);
  DuelPlayer get me => _ref.read(currentPlayerProvider);

  /// Make sure the backend knows about us (self-registration + heartbeat).
  Future<void> registerSelf() => _repo.registerSelf(me);

  /// Publish a freshly-played run as a challenge a friend can try to beat.
  /// [target] makes it a targeted challenge (lands in that player's inbox);
  /// otherwise it's an open challenge (quick-matchable, shareable by code).
  Future<DuelMatch> createChallenge({
    required String topic,
    required List<String> questionIds,
    required List<bool> answers,
    required int score,
    DuelPlayer? target,
  }) async {
    final duel = await _repo.createDuel(
      challenger: me,
      topic: topic,
      questionIds: questionIds,
      challengerAnswers: answers,
      challengerScore: score,
      targetOpponent: target,
    );
    _refresh();
    return duel;
  }

  /// Submit the local player's result as the opponent on [duel].
  Future<DuelMatch> submitResult({
    required DuelMatch duel,
    required int score,
  }) async {
    final completed = await _repo.submitOpponentResult(
      duelId: duel.id,
      opponent: me,
      opponentScore: score,
    );
    _refresh();
    return completed;
  }

  /// Resolve a scanned/typed code to a playable duel, or null if not found.
  Future<DuelMatch?> loadByCode(String code) => _repo.getDuelByCode(code);

  /// An open challenge to quick-match into, or null if the pool is empty.
  Future<DuelMatch?> findOpenChallenge() => _repo.findOpenChallenge(me.id);

  void _refresh() {
    _ref.invalidate(duelStatsProvider);
    _ref.invalidate(duelHistoryProvider);
    _ref.invalidate(incomingChallengesProvider);
    _ref.invalidate(duelPlayersProvider);
    _ref.invalidate(duelLeaderboardProvider);
  }
}
