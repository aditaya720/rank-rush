/// A card as published by the server on a round document.
class PlayingCard {
  const PlayingCard({
    required this.id,
    required this.suit,
    required this.rank,
    required this.numericRank,
    required this.code,
  });

  final String id;
  final String suit;
  final String rank;
  final int numericRank;
  final String code;

  bool get isRed => suit == 'hearts' || suit == 'diamonds';

  factory PlayingCard.fromMap(Map<String, dynamic> map) {
    return PlayingCard(
      id: (map['id'] as String?) ?? '',
      suit: (map['suit'] as String?) ?? 'spades',
      rank: (map['rank'] as String?) ?? 'ace',
      numericRank: (map['numericRank'] as num?)?.toInt() ?? 1,
      code: (map['code'] as String?) ?? '?',
    );
  }

  static PlayingCard? tryFromMap(Object? value) {
    if (value is Map) {
      return PlayingCard.fromMap(Map<String, dynamic>.from(value));
    }
    return null;
  }
}
