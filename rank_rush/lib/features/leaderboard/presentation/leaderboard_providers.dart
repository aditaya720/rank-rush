import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../shared/providers/firebase_providers.dart';
import '../domain/leaderboard_entry.dart';

class LeaderboardRepository {
  LeaderboardRepository(this._db);
  final FirebaseFirestore _db;

  Stream<List<LeaderboardEntry>> watchTopByBalance({int limit = 50}) {
    return _db
        .collection(Fs.leaderboard)
        .orderBy('virtualCoinBalance', descending: true)
        .limit(limit)
        .snapshots()
        .map((q) => q.docs.map(LeaderboardEntry.fromSnapshot).toList());
  }

  Stream<List<LeaderboardEntry>> watchTopByWeeklyWins({int limit = 50}) {
    return _db
        .collection(Fs.leaderboard)
        .orderBy('weeklyWins', descending: true)
        .limit(limit)
        .snapshots()
        .map((q) => q.docs.map(LeaderboardEntry.fromSnapshot).toList());
  }
}

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  return LeaderboardRepository(ref.watch(firestoreProvider));
});

final topByBalanceProvider = StreamProvider<List<LeaderboardEntry>>((ref) {
  return ref.watch(leaderboardRepositoryProvider).watchTopByBalance();
});

final topByWeeklyWinsProvider = StreamProvider<List<LeaderboardEntry>>((ref) {
  return ref.watch(leaderboardRepositoryProvider).watchTopByWeeklyWins();
});
