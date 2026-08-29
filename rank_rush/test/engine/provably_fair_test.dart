import 'package:flutter_test/flutter_test.dart';
import 'package:rank_rush/core/security/provably_fair.dart';

/// Canonical cross-language test vector.
///
/// These exact values were emitted by the authoritative TypeScript engine
/// (`functions/src/engine.ts`) for the fixed inputs below, and independently
/// reproduced by a Python re-implementation. If this test passes, the Dart
/// verifier reproduces the server byte-for-byte — which is the whole basis of
/// provable fairness.
const _seed =
    'a1b2c3d4e5f60718293a4b5c6d7e8f90112233445566778899aabbccddeeff00';
const _roundId = 'rnd_testvector_0001';
const _expectedSeedHash =
    '83418260fe3c7bf5063efde5c04315bab07ae31ea393e5adf84dbc7a52181eef';
const _expectedDeckHash =
    'aa1cf3a9ffcf871ec0f869607dccb29290eec5346d6bee738bbf52cd31f5e74d';
const _expectedDeckCodes = <String>[
  '4C', '7S', '8C', '3H', '4S', 'AD', 'KS', '9S', '8D', '2H', //
  'KH', '10H', '8S', 'AS', '9D', '10D', 'QH', 'KD', 'AC', 'JS',
  '2C', 'JD', '5S', '9C', '4D', '8H', '10S', '6H', 'QD', '5D',
  'QS', 'JH', '6D', '6S', '2S', 'AH', 'KC', '3D', '3S', 'JC',
  '6C', '5H', '2D', 'QC', '4H', '7H', '7C', '3C', '5C', '10C',
  '9H', '7D',
];

void main() {
  group('sha256Hex', () {
    test('matches the known server seed hash', () {
      expect(sha256Hex(_seed), _expectedSeedHash);
    });

    test('empty string has the standard SHA-256 digest', () {
      expect(
        sha256Hex(''),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });
  });

  group('canonical deck', () {
    test('has 52 unique cards indexed suit*13 + (rank-1)', () {
      final deck = ProvablyFair.buildCanonicalDeck();
      expect(deck.length, 52);
      expect(deck.map((c) => c.id).toSet().length, 52);
      // First card is the ace of hearts, last is the king of spades.
      expect(deck.first.code, 'AH');
      expect(deck.last.code, 'KS');
    });

    test('every rank appears exactly four times', () {
      final deck = ProvablyFair.buildCanonicalDeck();
      for (var rank = 1; rank <= 13; rank++) {
        expect(deck.where((c) => c.numericRank == rank).length, 4,
            reason: 'rank $rank should appear 4 times');
      }
    });
  });

  group('deterministic shuffle (cross-language vector)', () {
    test('reproduces the exact server deck order', () {
      final deck = ProvablyFair.shuffleDeck(_seed, _roundId);
      expect(deck.map((c) => c.code).toList(), _expectedDeckCodes);
    });

    test('reproduces the server deck hash', () {
      final deck = ProvablyFair.shuffleDeck(_seed, _roundId);
      expect(ProvablyFair.deckHashOf(deck), _expectedDeckHash);
    });

    test('shuffle is a permutation of the canonical deck', () {
      final canonical = ProvablyFair.buildCanonicalDeck().map((c) => c.id).toSet();
      final shuffled = ProvablyFair.shuffleDeck(_seed, _roundId).map((c) => c.id).toSet();
      expect(shuffled, canonical);
      expect(shuffled.length, 52);
    });

    test('is deterministic across repeated calls', () {
      final a = ProvablyFair.shuffleDeck(_seed, _roundId).map((c) => c.code).toList();
      final b = ProvablyFair.shuffleDeck(_seed, _roundId).map((c) => c.code).toList();
      expect(a, b);
    });

    test('different roundId yields a different order', () {
      final a = ProvablyFair.shuffleDeck(_seed, _roundId).map((c) => c.code).toList();
      final b = ProvablyFair.shuffleDeck(_seed, 'rnd_other').map((c) => c.code).toList();
      expect(a, isNot(equals(b)));
    });
  });

  group('computeRound', () {
    test('matches the server target, winner and winning index', () {
      final r = ProvablyFair.computeRound(_seed, _roundId);
      expect(r.targetCard.code, '4C');
      expect(r.targetCard.numericRank, 4);
      expect(r.winner, RevealSide.right);
      expect(r.winningIndex, 3);
      expect(r.revealSequence.length, 4);
      expect(r.serverSeedHash, _expectedSeedHash);
      expect(r.deckHash, _expectedDeckHash);
    });

    test('reveal alternates LEFT (even) / RIGHT (odd) and stops at match', () {
      final r = ProvablyFair.computeRound(_seed, _roundId);
      for (final step in r.revealSequence) {
        final expectedSide = step.index.isEven ? RevealSide.left : RevealSide.right;
        expect(step.side, expectedSide);
      }
      // The winning card genuinely matches the target rank.
      final winning = r.revealSequence.last;
      expect(winning.index, r.winningIndex);
      expect(winning.card.numericRank, r.targetCard.numericRank);
      // No earlier card matched the target rank.
      for (var i = 0; i < r.revealSequence.length - 1; i++) {
        expect(r.revealSequence[i].card.numericRank == r.targetCard.numericRank, isFalse);
      }
    });
  });

  group('verify', () {
    test('accepts a correctly-reported round', () {
      final v = ProvablyFair.verify(
        serverSeed: _seed,
        roundId: _roundId,
        reportedServerSeedHash: _expectedSeedHash,
        reportedDeckHash: _expectedDeckHash,
        reportedWinner: 'right',
        reportedTargetCode: '4C',
      );
      expect(v.isValid, isTrue);
      expect(v.seedHashMatches, isTrue);
      expect(v.deckHashMatches, isTrue);
      expect(v.winnerMatches, isTrue);
      expect(v.targetMatches, isTrue);
    });

    test('rejects a tampered winner', () {
      final v = ProvablyFair.verify(
        serverSeed: _seed,
        roundId: _roundId,
        reportedServerSeedHash: _expectedSeedHash,
        reportedDeckHash: _expectedDeckHash,
        reportedWinner: 'left', // tampered
        reportedTargetCode: '4C',
      );
      expect(v.isValid, isFalse);
      expect(v.winnerMatches, isFalse);
    });

    test('rejects a tampered seed (hash mismatch)', () {
      final v = ProvablyFair.verify(
        serverSeed: 'deadbeef', // does not hash to the committed value
        roundId: _roundId,
        reportedServerSeedHash: _expectedSeedHash,
        reportedDeckHash: _expectedDeckHash,
        reportedWinner: 'right',
        reportedTargetCode: '4C',
      );
      expect(v.seedHashMatches, isFalse);
      expect(v.isValid, isFalse);
    });
  });

  group('payoutFor', () {
    test('winner receives floor(stake * multiplier), loser receives 0', () {
      expect(ProvablyFair.payoutFor(500, RevealSide.right, RevealSide.right, 2.0), 1000);
      expect(ProvablyFair.payoutFor(500, RevealSide.left, RevealSide.right, 2.0), 0);
      // Floor is applied.
      expect(ProvablyFair.payoutFor(101, RevealSide.left, RevealSide.left, 1.95), 196);
    });
  });
}
