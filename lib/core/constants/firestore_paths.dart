/// Centralised Firestore path builders so collection/document names live in one
/// place and always match the Cloud Functions backend.
class Fs {
  const Fs._();

  // Top-level collections
  static const String users = 'users';
  static const String games = 'games';
  static const String leaderboard = 'leaderboardEntries';
  static const String config = 'config';
  static const String dailyRewards = 'dailyRewards';

  // Sub-collections
  static const String rounds = 'rounds';
  static const String bets = 'bets';
  static const String players = 'players';
  static const String transactions = 'transactions';
  static const String gameHistory = 'gameHistory';

  static String user(String uid) => '$users/$uid';
  static String transactionsOf(String uid) => '$users/$uid/$transactions';
  static String gameHistoryOf(String uid) => '$users/$uid/$gameHistory';

  static String game(String gameId) => '$games/$gameId';
  static String roundsOf(String gameId) => '$games/$gameId/$rounds';
  static String round(String gameId, String roundId) =>
      '$games/$gameId/$rounds/$roundId';
  static String playersOf(String gameId, String roundId) =>
      '${round(gameId, roundId)}/$players';
  static String betsOf(String gameId, String roundId) =>
      '${round(gameId, roundId)}/$bets';

  static const String gameConfigDoc = '$config/game';
}
