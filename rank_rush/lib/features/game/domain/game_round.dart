import 'package:cloud_firestore/cloud_firestore.dart';

import 'playing_card.dart';

enum GameStatus {
  waiting,
  betting,
  locked,
  revealing,
  finished,
  cancelled;

  static GameStatus fromWire(String? s) {
    switch (s) {
      case 'betting':
        return GameStatus.betting;
      case 'locked':
        return GameStatus.locked;
      case 'revealing':
        return GameStatus.revealing;
      case 'finished':
        return GameStatus.finished;
      case 'cancelled':
        return GameStatus.cancelled;
      default:
        return GameStatus.waiting;
    }
  }
}

enum BetSide {
  left,
  right;

  static BetSide? fromWire(String? s) {
    if (s == 'left') return BetSide.left;
    if (s == 'right') return BetSide.right;
    return null;
  }

  String get wire => this == BetSide.left ? 'left' : 'right';
  String get label => this == BetSide.left ? 'LEFT' : 'RIGHT';
}

/// One entry of the alternating reveal sequence.
class RoundRevealStep {
  const RoundRevealStep({required this.index, required this.side, required this.card});

  final int index;
  final BetSide side;
  final PlayingCard card;

  factory RoundRevealStep.fromMap(Map<String, dynamic> map) {
    return RoundRevealStep(
      index: (map['index'] as num?)?.toInt() ?? 0,
      side: BetSide.fromWire(map['side'] as String?) ?? BetSide.left,
      card: PlayingCard.fromMap(Map<String, dynamic>.from(map['card'] as Map)),
    );
  }
}

/// The authoritative, server-owned round. The client renders this and animates
/// the reveal, but never computes any outcome itself.
class GameRound {
  const GameRound({
    required this.id,
    required this.gameId,
    required this.status,
    required this.serverSeedHash,
    required this.targetCard,
    required this.targetNumericRank,
    required this.payoutMultiplier,
    required this.minBet,
    required this.maxBet,
    required this.revealIntervalMs,
    required this.playerCount,
    required this.leftPlayers,
    required this.rightPlayers,
    required this.leftStake,
    required this.rightStake,
    required this.bettingClosesAt,
    required this.serverSeed,
    required this.deckHash,
    required this.revealSequence,
    required this.winner,
    required this.winningIndex,
    required this.revealStartedAt,
    required this.revealDurationMs,
    required this.completedAt,
  });

  final String id;
  final String gameId;
  final GameStatus status;
  final String serverSeedHash;
  final PlayingCard? targetCard;
  final int targetNumericRank;
  final double payoutMultiplier;
  final int minBet;
  final int maxBet;
  final int revealIntervalMs;

  final int playerCount;
  final int leftPlayers;
  final int rightPlayers;
  final int leftStake;
  final int rightStake;

  final DateTime? bettingClosesAt;

  // Populated only at/after settlement:
  final String? serverSeed;
  final String? deckHash;
  final List<RoundRevealStep> revealSequence;
  final BetSide? winner;
  final int? winningIndex;
  final DateTime? revealStartedAt;
  final int? revealDurationMs;
  final DateTime? completedAt;

  bool get isBetting => status == GameStatus.betting;
  bool get isRevealing => status == GameStatus.revealing;
  bool get isFinished => status == GameStatus.finished;
  bool get isCancelled => status == GameStatus.cancelled;
  bool get isSettled => winner != null;

  /// Milliseconds of betting time left (>= 0).
  int millisLeftToBet(DateTime now) {
    final closes = bettingClosesAt;
    if (closes == null) return 0;
    final ms = closes.difference(now).inMilliseconds;
    return ms < 0 ? 0 : ms;
  }

  /// How many reveal cards should be visible given the elapsed reveal time.
  /// Drives the flip-by-flip animation purely from server timestamps.
  int visibleRevealCount(DateTime now) {
    if (revealSequence.isEmpty) return 0;
    if (status == GameStatus.finished || status == GameStatus.cancelled) {
      return revealSequence.length;
    }
    final start = revealStartedAt;
    if (start == null) return 0;
    final interval = revealIntervalMs <= 0 ? 700 : revealIntervalMs;
    final elapsed = now.difference(start).inMilliseconds;
    if (elapsed < 0) return 0;
    final count = (elapsed ~/ interval) + 1;
    if (count < 0) return 0;
    return count > revealSequence.length ? revealSequence.length : count;
  }

  factory GameRound.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final map = snap.data() ?? const <String, dynamic>{};
    DateTime? ts(Object? v) => v is Timestamp ? v.toDate() : null;

    final revealRaw = map['revealSequence'];
    final reveal = <RoundRevealStep>[];
    if (revealRaw is List) {
      for (final step in revealRaw) {
        if (step is Map) {
          reveal.add(RoundRevealStep.fromMap(Map<String, dynamic>.from(step)));
        }
      }
    }

    return GameRound(
      id: snap.id,
      gameId: (map['gameId'] as String?) ?? '',
      status: GameStatus.fromWire(map['status'] as String?),
      serverSeedHash: (map['serverSeedHash'] as String?) ?? '',
      targetCard: PlayingCard.tryFromMap(map['targetCard']),
      targetNumericRank: (map['targetNumericRank'] as num?)?.toInt() ?? 0,
      payoutMultiplier: (map['payoutMultiplier'] as num?)?.toDouble() ?? 2.0,
      minBet: (map['minBet'] as num?)?.toInt() ?? 0,
      maxBet: (map['maxBet'] as num?)?.toInt() ?? 0,
      revealIntervalMs: (map['revealIntervalMs'] as num?)?.toInt() ?? 700,
      playerCount: (map['playerCount'] as num?)?.toInt() ?? 0,
      leftPlayers: (map['leftPlayers'] as num?)?.toInt() ?? 0,
      rightPlayers: (map['rightPlayers'] as num?)?.toInt() ?? 0,
      leftStake: (map['leftStake'] as num?)?.toInt() ?? 0,
      rightStake: (map['rightStake'] as num?)?.toInt() ?? 0,
      bettingClosesAt: ts(map['bettingClosesAt']),
      serverSeed: map['serverSeed'] as String?,
      deckHash: map['deckHash'] as String?,
      revealSequence: reveal,
      winner: BetSide.fromWire(map['winner'] as String?),
      winningIndex: (map['winningIndex'] as num?)?.toInt(),
      revealStartedAt: ts(map['revealStartedAt']),
      revealDurationMs: (map['revealDurationMs'] as num?)?.toInt(),
      completedAt: ts(map['completedAt']),
    );
  }
}
