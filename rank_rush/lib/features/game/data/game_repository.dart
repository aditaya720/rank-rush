import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/constants/callables.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/bet.dart';
import '../domain/game_round.dart';

class PlaceBetResult {
  const PlaceBetResult({required this.betId, required this.status, required this.newBalance});
  final String betId;
  final String status;
  final int newBalance;
}

class GameRepository {
  GameRepository({required FirebaseFirestore firestore, required FirebaseFunctions functions})
      : _db = firestore,
        _functions = functions;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  /// The current round id for a game table (null before the first round).
  Stream<String?> watchCurrentRoundId(String gameId) {
    return _db.doc(Fs.game(gameId)).snapshots().map(
          (snap) => snap.data()?['currentRoundId'] as String?,
        );
  }

  /// Live stream of a specific round document.
  Stream<GameRound?> watchRound(String gameId, String roundId) {
    return _db.doc(Fs.round(gameId, roundId)).snapshots().map(
          (snap) => snap.exists ? GameRound.fromSnapshot(snap) : null,
        );
  }

  /// The current user's bet on a round, if any.
  Stream<Bet?> watchMyBet(String gameId, String roundId, String uid) {
    return _db
        .collection(Fs.betsOf(gameId, roundId))
        .where('uid', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .map((q) => q.docs.isEmpty ? null : Bet.fromSnapshot(q.docs.first));
  }

  /// Places a virtual-coin bet. `betId` is a client idempotency key.
  Future<PlaceBetResult> placeBet({
    required String gameId,
    required String roundId,
    required String betId,
    required BetSide side,
    required int stake,
  }) async {
    try {
      final res = await _functions.httpsCallable(Callables.placeBet).call<Map<String, dynamic>>({
        'gameId': gameId,
        'roundId': roundId,
        'betId': betId,
        'side': side.wire,
        'stake': stake,
      });
      final data = res.data;
      return PlaceBetResult(
        betId: (data['betId'] as String?) ?? betId,
        status: (data['status'] as String?) ?? 'placed',
        newBalance: (data['newBalance'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      throw mapError(e);
    }
  }

  /// Nudges the server to advance the shared game (create/settle/next). Safe to
  /// call periodically; failures are swallowed since it is only a liveness hint.
  Future<void> syncRound(String gameId) async {
    try {
      await _functions
          .httpsCallable(Callables.syncRound)
          .call<Map<String, dynamic>>({'gameId': gameId});
    } catch (_) {
      // Non-fatal: the scheduled backstop also advances the game.
    }
  }
}
