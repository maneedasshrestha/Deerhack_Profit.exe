import 'package:flutter/foundation.dart';

/// Lifecycle of an async duel.
enum DuelStatus {
  /// Challenger has played; waiting for an opponent to accept and play.
  awaitingOpponent,

  /// Both players have played — [DuelMatch.winnerId] is resolved.
  completed,
}

/// Which side of a duel the local player is on.
enum DuelRole { challenger, opponent }

DuelStatus _statusFrom(String? raw) => switch (raw) {
      'completed' => DuelStatus.completed,
      _ => DuelStatus.awaitingOpponent,
    };

String _statusTo(DuelStatus s) => switch (s) {
      DuelStatus.completed => 'completed',
      DuelStatus.awaitingOpponent => 'awaiting_opponent',
    };

// ═══════════════════════════════════════════════════════════════════════════
// DuelMatch — one async head-to-head. The challenger creates it and plays
// first; the opponent loads the SAME question_ids later (via the short code or
// a targeted challenge) and plays. The winner is then computed and persisted.
// ═══════════════════════════════════════════════════════════════════════════
@immutable
class DuelMatch {
  const DuelMatch({
    required this.id,
    required this.code,
    required this.topic,
    required this.questionIds,
    required this.challengerId,
    required this.challengerName,
    this.challengerAnswers = const [],
    this.challengerScore,
    this.challengerFinishedAt,
    this.opponentId,
    this.opponentName,
    this.opponentScore,
    this.opponentFinishedAt,
    this.winnerId,
    this.status = DuelStatus.awaitingOpponent,
    this.createdAt,
  });

  final String id;

  /// Short, shareable code carried by the QR / typed manually (e.g. ABC-DEF).
  final String code;
  final String topic;

  /// Ordered question ids; both players resolve these against the bundled bank.
  final List<String> questionIds;

  final String challengerId;
  final String challengerName;

  /// Per-question correctness of the challenger's run — replayed as a "ghost"
  /// race for the opponent so the existing race visuals stay faithful.
  final List<bool> challengerAnswers;
  final int? challengerScore;
  final DateTime? challengerFinishedAt;

  final String? opponentId;
  final String? opponentName;
  final int? opponentScore;
  final DateTime? opponentFinishedAt;

  /// Player id of the winner, or null for a draw / not yet completed.
  final String? winnerId;
  final DuelStatus status;
  final DateTime? createdAt;

  int get questionCount => questionIds.length;

  bool get isCompleted => status == DuelStatus.completed;

  /// True once a draw is settled (completed with no winner).
  bool get isDraw => isCompleted && winnerId == null;

  /// The side [playerId] is on, or null if they aren't a participant.
  DuelRole? roleOf(String playerId) {
    if (playerId == challengerId) return DuelRole.challenger;
    if (playerId == opponentId) return DuelRole.opponent;
    return null;
  }

  /// This player's own score (null if they haven't played yet).
  int? myScore(String playerId) =>
      roleOf(playerId) == DuelRole.opponent ? opponentScore : challengerScore;

  /// The other side's score from this player's perspective.
  int? theirScore(String playerId) =>
      roleOf(playerId) == DuelRole.opponent ? challengerScore : opponentScore;

  /// The other side's display name from this player's perspective.
  String opponentDisplayFor(String playerId) =>
      roleOf(playerId) == DuelRole.opponent
          ? challengerName
          : (opponentName ?? 'Opponent');

  /// 'win' | 'loss' | 'draw' for a completed duel, from [playerId]'s view.
  String? outcomeFor(String playerId) {
    if (!isCompleted) return null;
    if (winnerId == null) return 'draw';
    return winnerId == playerId ? 'win' : 'loss';
  }

  DuelMatch copyWith({
    String? opponentId,
    String? opponentName,
    int? opponentScore,
    DateTime? opponentFinishedAt,
    String? winnerId,
    DuelStatus? status,
  }) =>
      DuelMatch(
        id: id,
        code: code,
        topic: topic,
        questionIds: questionIds,
        challengerId: challengerId,
        challengerName: challengerName,
        challengerAnswers: challengerAnswers,
        challengerScore: challengerScore,
        challengerFinishedAt: challengerFinishedAt,
        opponentId: opponentId ?? this.opponentId,
        opponentName: opponentName ?? this.opponentName,
        opponentScore: opponentScore ?? this.opponentScore,
        opponentFinishedAt: opponentFinishedAt ?? this.opponentFinishedAt,
        winnerId: winnerId ?? this.winnerId,
        status: status ?? this.status,
        createdAt: createdAt,
      );

  factory DuelMatch.fromJson(Map<String, dynamic> json) {
    List<String> ids(dynamic v) =>
        (v as List?)?.map((e) => e.toString()).toList() ?? const [];
    List<bool> bools(dynamic v) =>
        (v as List?)?.map((e) => e == true).toList() ?? const [];
    DateTime? date(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    return DuelMatch(
      id: json['id'] as String,
      code: json['code'] as String,
      topic: json['topic'] as String? ?? 'Mixed',
      questionIds: ids(json['question_ids']),
      challengerId: json['challenger_id'] as String,
      challengerName: json['challenger_name'] as String? ?? 'Challenger',
      challengerAnswers: bools(json['challenger_answers']),
      challengerScore: json['challenger_score'] as int?,
      challengerFinishedAt: date(json['challenger_finished_at']),
      opponentId: json['opponent_id'] as String?,
      opponentName: json['opponent_name'] as String?,
      opponentScore: json['opponent_score'] as int?,
      opponentFinishedAt: date(json['opponent_finished_at']),
      winnerId: json['winner_id'] as String?,
      status: _statusFrom(json['status'] as String?),
      createdAt: date(json['created_at']),
    );
  }

  /// Columns for creating the row (challenger has just played).
  Map<String, dynamic> toInsertJson() => {
        'code': code,
        'topic': topic,
        'question_ids': questionIds,
        'challenger_id': challengerId,
        'challenger_name': challengerName,
        'challenger_answers': challengerAnswers,
        'challenger_score': challengerScore,
        'challenger_finished_at': challengerFinishedAt?.toIso8601String(),
        'opponent_id': opponentId,
        'opponent_name': opponentName,
        'status': _statusTo(status),
      };
}
