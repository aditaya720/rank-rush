/// Provably-fair verification — the Dart mirror of the server engine.
///
/// This file re-implements, byte-for-byte, the algorithm in the Cloud Functions
/// backend (`functions/src/fairness.ts` + `functions/src/engine.ts`). Because
/// the deck order is derived deterministically from `(serverSeed, roundId)`,
/// anyone can recompute a finished round entirely on-device and confirm that:
///
///   1. `SHA256(serverSeed) == serverSeedHash` that was published *before* the
///      round (so the server committed to the outcome in advance), and
///   2. the recomputed deck hash, target card and winner match what the server
///      reported.
///
/// It has ZERO Flutter/Firebase dependencies on purpose, so it can be unit
/// tested in isolation and trusted as a pure function of its inputs. See
/// `docs/FAIRNESS.md` for the byte-level specification and `test/engine/` for
/// the cross-language test vector.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Hex-encoded SHA-256 of a UTF-8 string. Mirrors `sha256Hex` on the server.
String sha256Hex(String input) => sha256.convert(utf8.encode(input)).toString();

/// A single card as produced by the deterministic engine.
class FairCard {
  const FairCard({
    required this.id,
    required this.suit,
    required this.rank,
    required this.numericRank,
    required this.code,
  });

  /// Canonical id, e.g. `seven_hearts`.
  final String id;

  /// `hearts` | `diamonds` | `clubs` | `spades`.
  final String suit;

  /// `ace` | `two` | ... | `king`.
  final String rank;

  /// ace = 1 .. king = 13.
  final int numericRank;

  /// Short code, e.g. `7H`, `10D`, `AS`.
  final String code;
}

/// `left` owns even reveal indices (0, 2, ...), `right` owns odd indices.
enum RevealSide {
  left,
  right;

  static RevealSide fromString(String s) =>
      s == 'right' ? RevealSide.right : RevealSide.left;

  String get wire => this == RevealSide.right ? 'right' : 'left';
}

/// One step of the alternating reveal.
class FairRevealStep {
  const FairRevealStep({
    required this.index,
    required this.side,
    required this.card,
  });

  final int index;
  final RevealSide side;
  final FairCard card;
}

/// Deterministic PRNG driven by SHA-256 — the exact mirror of the server's
/// `SeededRng`.
///
/// Byte stream: for k = 0, 1, 2, ...
///   block(k) = SHA256( UTF8( "$serverSeed:$roundId:$k" ) )   // 32 bytes
/// consumed 4 bytes at a time as big-endian unsigned 32-bit integers, with
/// rejection sampling for unbiased `nextInt`.
class SeededRng {
  SeededRng(this.serverSeed, this.roundId);

  final String serverSeed;
  final String roundId;

  int _blockIndex = 0;
  Uint8List _buffer = Uint8List(0);
  int _offset = 0;

  void _refill() {
    final block = Uint8List.fromList(
      sha256.convert(utf8.encode('$serverSeed:$roundId:$_blockIndex')).bytes,
    );
    _blockIndex += 1;
    final remaining = _buffer.length - _offset;
    final combined = Uint8List(remaining + block.length);
    combined.setRange(0, remaining, _buffer, _offset);
    combined.setRange(remaining, remaining + block.length, block);
    _buffer = combined;
    _offset = 0;
  }

  int _nextUint32() {
    if (_buffer.length - _offset < 4) {
      _refill();
    }
    final o = _offset;
    final value = (_buffer[o] << 24) |
        (_buffer[o + 1] << 16) |
        (_buffer[o + 2] << 8) |
        _buffer[o + 3];
    _offset += 4;
    return value & 0xFFFFFFFF;
  }

  /// Uniform integer in [0, n). Requires 1 <= n <= 2^32.
  int nextInt(int n) {
    if (n <= 0) {
      throw ArgumentError('nextInt requires a positive integer, got $n');
    }
    if (n == 1) return 0;
    // Largest multiple of n strictly below 2^32.
    final limit = (0x100000000 ~/ n) * n;
    var x = _nextUint32();
    while (x >= limit) {
      x = _nextUint32();
    }
    return x % n;
  }
}

/// The full deterministic outcome of a round, recomputed on-device.
class FairRound {
  const FairRound({
    required this.roundId,
    required this.serverSeed,
    required this.serverSeedHash,
    required this.deck,
    required this.deckHash,
    required this.targetCard,
    required this.revealSequence,
    required this.winner,
    required this.winningIndex,
  });

  final String roundId;
  final String serverSeed;
  final String serverSeedHash;
  final List<FairCard> deck;
  final String deckHash;
  final FairCard targetCard;
  final List<FairRevealStep> revealSequence;
  final RevealSide winner;
  final int winningIndex;
}

/// Result of comparing a server-reported round against a local recomputation.
class FairnessVerification {
  const FairnessVerification({
    required this.seedHashMatches,
    required this.deckHashMatches,
    required this.winnerMatches,
    required this.targetMatches,
    required this.recomputed,
  });

  final bool seedHashMatches;
  final bool deckHashMatches;
  final bool winnerMatches;
  final bool targetMatches;
  final FairRound recomputed;

  /// True only when every independently-checkable field agrees.
  bool get isValid =>
      seedHashMatches && deckHashMatches && winnerMatches && targetMatches;
}

/// Pure, deterministic 52-card engine — the client-side mirror of the server.
class ProvablyFair {
  ProvablyFair._();

  /// Canonical suit order used when building the unshuffled deck.
  static const List<String> suits = ['hearts', 'diamonds', 'clubs', 'spades'];

  /// Canonical rank order (ace-low). numericRank is ace = 1 .. king = 13.
  static const List<({String name, int numeric, String code})> ranks = [
    (name: 'ace', numeric: 1, code: 'A'),
    (name: 'two', numeric: 2, code: '2'),
    (name: 'three', numeric: 3, code: '3'),
    (name: 'four', numeric: 4, code: '4'),
    (name: 'five', numeric: 5, code: '5'),
    (name: 'six', numeric: 6, code: '6'),
    (name: 'seven', numeric: 7, code: '7'),
    (name: 'eight', numeric: 8, code: '8'),
    (name: 'nine', numeric: 9, code: '9'),
    (name: 'ten', numeric: 10, code: '10'),
    (name: 'jack', numeric: 11, code: 'J'),
    (name: 'queen', numeric: 12, code: 'Q'),
    (name: 'king', numeric: 13, code: 'K'),
  ];

  static const Map<String, String> suitCode = {
    'hearts': 'H',
    'diamonds': 'D',
    'clubs': 'C',
    'spades': 'S',
  };

  /// Builds the 52-card deck in canonical (unshuffled) order.
  /// Index = suitIndex * 13 + (numericRank - 1).
  static List<FairCard> buildCanonicalDeck() {
    final deck = <FairCard>[];
    for (final suit in suits) {
      for (final rank in ranks) {
        deck.add(FairCard(
          id: '${rank.name}_$suit',
          suit: suit,
          rank: rank.name,
          numericRank: rank.numeric,
          code: '${rank.code}${suitCode[suit]}',
        ));
      }
    }
    return deck;
  }

  /// Deterministic seeded Fisher-Yates shuffle. Identical output to the server
  /// for the same `(serverSeed, roundId)`.
  static List<FairCard> shuffleDeck(String serverSeed, String roundId) {
    final deck = buildCanonicalDeck();
    final rng = SeededRng(serverSeed, roundId);
    for (var i = deck.length - 1; i >= 1; i--) {
      final j = rng.nextInt(i + 1); // 0..i inclusive
      final tmp = deck[i];
      deck[i] = deck[j];
      deck[j] = tmp;
    }
    return deck;
  }

  /// SHA-256 over the comma-joined card ids of a deck (order-sensitive).
  static String deckHashOf(List<FairCard> deck) =>
      sha256Hex(deck.map((c) => c.id).join(','));

  /// Alternating LEFT/RIGHT reveal that stops at the first card matching the
  /// target rank. LEFT owns even indices, RIGHT owns odd.
  static ({List<FairRevealStep> steps, RevealSide winner, int winningIndex})
      computeReveal(List<FairCard> remaining, int targetNumericRank) {
    final steps = <FairRevealStep>[];
    for (var i = 0; i < remaining.length; i++) {
      final side = i.isEven ? RevealSide.left : RevealSide.right;
      final card = remaining[i];
      steps.add(FairRevealStep(index: i, side: side, card: card));
      if (card.numericRank == targetNumericRank) {
        return (steps: steps, winner: side, winningIndex: i);
      }
    }
    throw StateError(
      'No target-rank card found in remaining deck (impossible for a valid deck).',
    );
  }

  /// Full authoritative computation for a round, deterministic in
  /// `(serverSeed, roundId)`.
  static FairRound computeRound(String serverSeed, String roundId) {
    final deck = shuffleDeck(serverSeed, roundId);
    final targetCard = deck.first;
    final remaining = deck.sublist(1); // 51 cards; target removed
    final outcome = computeReveal(remaining, targetCard.numericRank);
    return FairRound(
      roundId: roundId,
      serverSeed: serverSeed,
      serverSeedHash: sha256Hex(serverSeed),
      deck: deck,
      deckHash: deckHashOf(deck),
      targetCard: targetCard,
      revealSequence: outcome.steps,
      winner: outcome.winner,
      winningIndex: outcome.winningIndex,
    );
  }

  /// Recomputes a finished round from its revealed `serverSeed` and compares it
  /// against the values the server reported. Every field is checked
  /// independently so the UI can show exactly what matched.
  static FairnessVerification verify({
    required String serverSeed,
    required String roundId,
    required String reportedServerSeedHash,
    required String reportedDeckHash,
    required String reportedWinner,
    required String reportedTargetCode,
  }) {
    final recomputed = computeRound(serverSeed, roundId);
    return FairnessVerification(
      seedHashMatches: recomputed.serverSeedHash == reportedServerSeedHash,
      deckHashMatches: recomputed.deckHash == reportedDeckHash,
      winnerMatches: recomputed.winner.wire == reportedWinner,
      targetMatches: recomputed.targetCard.code == reportedTargetCode,
      recomputed: recomputed,
    );
  }

  /// Virtual-coin return for a single bet (0 if it lost). Mirrors `payoutFor`.
  static int payoutFor(int stake, RevealSide side, RevealSide winner, double multiplier) =>
      side == winner ? (stake * multiplier).floor() : 0;
}
