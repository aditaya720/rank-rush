import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors the server `TransactionType` union.
enum CoinTxType {
  bet,
  win,
  loss,
  bonus,
  refund,
  adminAdjustment,
  unknown;

  static CoinTxType fromWire(String? s) {
    switch (s) {
      case 'BET':
        return CoinTxType.bet;
      case 'WIN':
        return CoinTxType.win;
      case 'LOSS':
        return CoinTxType.loss;
      case 'BONUS':
        return CoinTxType.bonus;
      case 'REFUND':
        return CoinTxType.refund;
      case 'ADMIN_ADJUSTMENT':
        return CoinTxType.adminAdjustment;
      default:
        return CoinTxType.unknown;
    }
  }

  String get label {
    switch (this) {
      case CoinTxType.bet:
        return 'Bet placed';
      case CoinTxType.win:
        return 'Win';
      case CoinTxType.loss:
        return 'Loss';
      case CoinTxType.bonus:
        return 'Bonus';
      case CoinTxType.refund:
        return 'Refund';
      case CoinTxType.adminAdjustment:
        return 'Adjustment';
      case CoinTxType.unknown:
        return 'Transaction';
    }
  }
}

/// An immutable ledger entry from `users/{uid}/transactions`.
class CoinTransaction {
  const CoinTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.roundId,
    required this.timestamp,
  });

  final String id;
  final CoinTxType type;
  final int amount; // signed delta
  final int balanceAfter;
  final String? roundId;
  final DateTime? timestamp;

  factory CoinTransaction.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final map = snap.data() ?? const {};
    final ts = map['timestamp'];
    return CoinTransaction(
      id: snap.id,
      type: CoinTxType.fromWire(map['type'] as String?),
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      balanceAfter: (map['balanceAfter'] as num?)?.toInt() ?? 0,
      roundId: map['roundId'] as String?,
      timestamp: ts is Timestamp ? ts.toDate() : null,
    );
  }
}
