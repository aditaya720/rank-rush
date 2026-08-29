import 'package:intl/intl.dart';

/// Small formatting helpers used across the UI.
class Formatters {
  const Formatters._();

  static final NumberFormat _coins = NumberFormat.decimalPattern();

  /// 12345 -> "12,345"
  static String coins(num value) => _coins.format(value);

  /// Signed coin delta, e.g. +1,000 / -500.
  static String signedCoins(int value) {
    final formatted = _coins.format(value.abs());
    if (value > 0) return '+$formatted';
    if (value < 0) return '-$formatted';
    return '0';
  }

  static String multiplier(double m) {
    final s = m.toStringAsFixed(2);
    return s.endsWith('0') ? '${m.toStringAsFixed(1)}x' : '${s}x';
  }

  /// Short humanised time, e.g. "just now", "3m ago".
  static String relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.yMMMd().format(time);
  }

  static String clockMmSs(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Short suit glyph from a suit name.
  static String suitGlyph(String suit) {
    switch (suit) {
      case 'hearts':
        return '♥'; // ♥
      case 'diamonds':
        return '♦'; // ♦
      case 'clubs':
        return '♣'; // ♣
      case 'spades':
        return '♠'; // ♠
      default:
        return '?';
    }
  }

  /// Rank label from a numeric rank (1..13).
  static String rankLabel(int numericRank) {
    switch (numericRank) {
      case 1:
        return 'A';
      case 11:
        return 'J';
      case 12:
        return 'Q';
      case 13:
        return 'K';
      default:
        return '$numericRank';
    }
  }

  static String rankWord(int numericRank) {
    const words = [
      'Ace', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', //
      'Eight', 'Nine', 'Ten', 'Jack', 'Queen', 'King',
    ];
    if (numericRank < 1 || numericRank > 13) return '?';
    return words[numericRank - 1];
  }
}
