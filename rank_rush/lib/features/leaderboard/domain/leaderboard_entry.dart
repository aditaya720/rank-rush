import 'package:cloud_firestore/cloud_firestore.dart';

/// A public, privacy-safe leaderboard row (no PII — display name + avatar only).
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.avatar,
    required this.virtualCoinBalance,
    required this.totalWins,
    required this.gamesPlayed,
    required this.weeklyWins,
  });

  final String uid;
  final String displayName;
  final String avatar;
  final int virtualCoinBalance;
  final int totalWins;
  final int gamesPlayed;
  final int weeklyWins;

  factory LeaderboardEntry.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final map = snap.data() ?? const {};
    return LeaderboardEntry(
      uid: snap.id,
      displayName: (map['displayName'] as String?) ?? 'Player',
      avatar: (map['avatar'] as String?) ?? 'av_0',
      virtualCoinBalance: (map['virtualCoinBalance'] as num?)?.toInt() ?? 0,
      totalWins: (map['totalWins'] as num?)?.toInt() ?? 0,
      gamesPlayed: (map['gamesPlayed'] as num?)?.toInt() ?? 0,
      weeklyWins: (map['weeklyWins'] as num?)?.toInt() ?? 0,
    );
  }
}
