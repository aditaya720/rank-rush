import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../game/domain/game_round.dart';
import '../../shared/providers/firebase_providers.dart';

/// The most recently *settled* round for the default table, with its
/// `serverSeed` revealed — this gives the fairness screen a real round to
/// verify when it's opened from the menu (not just from a finished game).
///
/// Ordering by `completedAt` needs only the automatic single-field index, so no
/// custom composite index is required. We fetch a small window and pick the
/// newest round that is fully settled (seed revealed).
final lastFinishedRoundProvider = StreamProvider<GameRound?>((ref) {
  final db = ref.watch(firestoreProvider);
  return db
      .collection(Fs.roundsOf(AppConfig.gameId))
      .orderBy('completedAt', descending: true)
      .limit(6)
      .snapshots()
      .map((q) {
    for (final doc in q.docs) {
      final round = GameRound.fromSnapshot(doc);
      if (round.isFinished &&
          round.serverSeed != null &&
          round.serverSeed!.isNotEmpty) {
        return round;
      }
    }
    return null;
  });
});
