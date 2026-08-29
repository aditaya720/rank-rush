import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/constants/callables.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/coin_transaction.dart';
import '../domain/user_profile.dart';

class DailyBonusResult {
  const DailyBonusResult({required this.amount, required this.streak, required this.newBalance});
  final int amount;
  final int streak;
  final int newBalance;
}

class WalletRepository {
  WalletRepository({required FirebaseFirestore firestore, required FirebaseFunctions functions})
      : _db = firestore,
        _functions = functions;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  /// Live stream of the user's profile (balance, stats, self-exclusion).
  Stream<UserProfile?> watchProfile(String uid) {
    return _db.doc(Fs.user(uid)).snapshots().map(
          (snap) => snap.exists ? UserProfile.fromSnapshot(snap) : null,
        );
  }

  /// Live stream of the most recent ledger entries.
  Stream<List<CoinTransaction>> watchTransactions(String uid, {int limit = 50}) {
    return _db
        .collection(Fs.transactionsOf(uid))
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((q) => q.docs.map(CoinTransaction.fromSnapshot).toList());
  }

  Future<DailyBonusResult> claimDailyBonus() async {
    try {
      final res = await _functions
          .httpsCallable(Callables.claimDailyBonus)
          .call<Map<String, dynamic>>();
      final data = res.data;
      return DailyBonusResult(
        amount: (data['amount'] as num?)?.toInt() ?? 0,
        streak: (data['streak'] as num?)?.toInt() ?? 1,
        newBalance: (data['newBalance'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<DateTime> selfExclude({required int hours}) async {
    try {
      final res = await _functions
          .httpsCallable(Callables.selfExclude)
          .call<Map<String, dynamic>>({'hours': hours});
      final until = (res.data['selfExcludedUntil'] as num?)?.toInt() ?? 0;
      return DateTime.fromMillisecondsSinceEpoch(until);
    } catch (e) {
      throw mapError(e);
    }
  }
}
