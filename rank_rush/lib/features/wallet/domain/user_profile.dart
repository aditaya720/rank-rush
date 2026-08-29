import 'package:cloud_firestore/cloud_firestore.dart';

/// A player's server-owned profile. The client only ever READS this; all
/// mutations happen in Cloud Functions.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.avatar,
    required this.virtualCoinBalance,
    required this.totalGames,
    required this.totalWins,
    required this.totalLosses,
    required this.role,
    required this.selfExcludedUntil,
  });

  final String uid;
  final String displayName;
  final String avatar;
  final int virtualCoinBalance;
  final int totalGames;
  final int totalWins;
  final int totalLosses;
  final String role;
  final DateTime? selfExcludedUntil;

  bool get isAdmin => role == 'ADMIN' || role == 'SUPER_ADMIN';

  bool get isSelfExcluded =>
      selfExcludedUntil != null && selfExcludedUntil!.isAfter(DateTime.now());

  double get winRate => totalGames == 0 ? 0 : totalWins / totalGames;

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    final excluded = map['selfExcludedUntil'];
    return UserProfile(
      uid: uid,
      displayName: (map['displayName'] as String?) ?? 'Player',
      avatar: (map['avatar'] as String?) ?? 'av_0',
      virtualCoinBalance: (map['virtualCoinBalance'] as num?)?.toInt() ?? 0,
      totalGames: (map['totalGames'] as num?)?.toInt() ?? 0,
      totalWins: (map['totalWins'] as num?)?.toInt() ?? 0,
      totalLosses: (map['totalLosses'] as num?)?.toInt() ?? 0,
      role: (map['role'] as String?) ?? 'USER',
      selfExcludedUntil: excluded is num
          ? DateTime.fromMillisecondsSinceEpoch(excluded.toInt())
          : null,
    );
  }

  factory UserProfile.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    return UserProfile.fromMap(snap.id, snap.data() ?? const {});
  }
}
