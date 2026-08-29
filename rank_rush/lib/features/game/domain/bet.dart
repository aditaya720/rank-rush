import 'package:cloud_firestore/cloud_firestore.dart';

import 'game_round.dart';

/// The current user's bet on a round (read back from
/// `games/{gameId}/rounds/{roundId}/bets/{betId}`).
class Bet {
  const Bet({
    required this.betId,
    required this.roundId,
    required this.side,
    required this.stake,
    required this.status,
    required this.payout,
    required this.netProfit,
  });

  final String betId;
  final String roundId;
  final BetSide side;
  final int stake;
  final String status; // placed | settled | refunded
  final int payout;
  final int netProfit;

  bool get isSettled => status == 'settled';
  bool get isPlaced => status == 'placed';
  bool get won => isSettled && payout > 0;

  factory Bet.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final map = snap.data() ?? const {};
    return Bet(
      betId: (map['betId'] as String?) ?? snap.id,
      roundId: (map['roundId'] as String?) ?? '',
      side: BetSide.fromWire(map['side'] as String?) ?? BetSide.left,
      stake: (map['stake'] as num?)?.toInt() ?? 0,
      status: (map['status'] as String?) ?? 'placed',
      payout: (map['payout'] as num?)?.toInt() ?? 0,
      netProfit: (map['netProfit'] as num?)?.toInt() ?? 0,
    );
  }
}
