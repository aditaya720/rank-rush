/**
 * Pure, deterministic 52-card game engine.
 *
 * No Firebase / IO imports live here so the engine can be unit-tested in
 * isolation (see selftest.ts) and mirrored on the Flutter client for
 * independent fairness verification.
 */

import { CardData, RankName, RevealStep, Side, Suit } from "./types";
import { sha256Hex, SeededRng } from "./fairness";

/** Canonical suit order used when building the unshuffled deck. */
export const SUITS: readonly Suit[] = ["hearts", "diamonds", "clubs", "spades"];

/** Canonical rank order (ace-low). numericRank is ace=1 .. king=13. */
export const RANKS: ReadonlyArray<{ name: RankName; numeric: number; code: string }> = [
  { name: "ace", numeric: 1, code: "A" },
  { name: "two", numeric: 2, code: "2" },
  { name: "three", numeric: 3, code: "3" },
  { name: "four", numeric: 4, code: "4" },
  { name: "five", numeric: 5, code: "5" },
  { name: "six", numeric: 6, code: "6" },
  { name: "seven", numeric: 7, code: "7" },
  { name: "eight", numeric: 8, code: "8" },
  { name: "nine", numeric: 9, code: "9" },
  { name: "ten", numeric: 10, code: "10" },
  { name: "jack", numeric: 11, code: "J" },
  { name: "queen", numeric: 12, code: "Q" },
  { name: "king", numeric: 13, code: "K" },
];

const SUIT_CODE: Record<Suit, string> = {
  hearts: "H",
  diamonds: "D",
  clubs: "C",
  spades: "S",
};

/**
 * Builds the 52-card deck in canonical (unshuffled) order.
 * Index = suitIndex * 13 + (numericRank - 1).
 */
export function buildCanonicalDeck(): CardData[] {
  const deck: CardData[] = [];
  for (const suit of SUITS) {
    for (const rank of RANKS) {
      deck.push({
        id: `${rank.name}_${suit}`,
        suit,
        rank: rank.name,
        numericRank: rank.numeric,
        code: `${rank.code}${SUIT_CODE[suit]}`,
      });
    }
  }
  return deck;
}

/**
 * Deterministically shuffles a fresh canonical deck using a seeded
 * Fisher-Yates. Given the same (serverSeed, roundId) the output is identical
 * on server and client.
 */
export function shuffleDeck(serverSeed: string, roundId: string): CardData[] {
  const deck = buildCanonicalDeck();
  const rng = new SeededRng(serverSeed, roundId);
  for (let i = deck.length - 1; i >= 1; i--) {
    const j = rng.nextInt(i + 1); // 0..i inclusive
    const tmp = deck[i];
    deck[i] = deck[j];
    deck[j] = tmp;
  }
  return deck;
}

/** SHA-256 over the comma-joined card ids of a deck (order-sensitive). */
export function deckHashOf(deck: CardData[]): string {
  return sha256Hex(deck.map((c) => c.id).join(","));
}

export interface RevealOutcome {
  steps: RevealStep[];
  winner: Side;
  winningIndex: number;
}

/**
 * Walks the post-target "remaining" deck, alternating LEFT/RIGHT, and stops at
 * the first card whose rank matches the target. LEFT owns even indices (0,2,..)
 * and RIGHT owns odd indices. Because exactly three of the target rank's four
 * cards remain after the target is drawn, a match is guaranteed.
 */
export function computeReveal(remaining: CardData[], targetNumericRank: number): RevealOutcome {
  const steps: RevealStep[] = [];
  for (let i = 0; i < remaining.length; i++) {
    const side: Side = i % 2 === 0 ? "left" : "right";
    const card = remaining[i];
    steps.push({ index: i, side, card });
    if (card.numericRank === targetNumericRank) {
      return { steps, winner: side, winningIndex: i };
    }
  }
  throw new Error("No target-rank card found in remaining deck (impossible for a valid 52-card deck).");
}

export interface RoundComputation {
  roundId: string;
  serverSeed: string;
  serverSeedHash: string;
  deck: CardData[];
  deckHash: string;
  targetCard: CardData;
  targetRank: RankName;
  targetNumericRank: number;
  revealSequence: RevealStep[];
  winner: Side;
  winningIndex: number;
}

/**
 * Full authoritative computation for a round: shuffle -> draw target ->
 * remove target -> alternating reveal -> winner. Deterministic in
 * (serverSeed, roundId).
 */
export function computeRound(serverSeed: string, roundId: string): RoundComputation {
  const deck = shuffleDeck(serverSeed, roundId);
  const targetCard = deck[0];
  const remaining = deck.slice(1); // 51 cards; target removed
  const outcome = computeReveal(remaining, targetCard.numericRank);
  return {
    roundId,
    serverSeed,
    serverSeedHash: sha256Hex(serverSeed),
    deck,
    deckHash: deckHashOf(deck),
    targetCard,
    targetRank: targetCard.rank,
    targetNumericRank: targetCard.numericRank,
    revealSequence: outcome.steps,
    winner: outcome.winner,
    winningIndex: outcome.winningIndex,
  };
}

/** Virtual-coin return for a single bet (0 if it lost). */
export function payoutFor(
  stake: number,
  side: Side,
  winner: Side,
  multiplier: number,
): number {
  return side === winner ? Math.floor(stake * multiplier) : 0;
}

/**
 * Net virtual-coin change over the whole round for one bet. The stake is
 * debited when the bet is placed; the winner receives floor(stake*multiplier)
 * back, so net = payout - stake for a win, and -stake for a loss.
 */
export function netProfitFor(
  stake: number,
  side: Side,
  winner: Side,
  multiplier: number,
): number {
  return payoutFor(stake, side, winner, multiplier) - stake;
}
