/**
 * Standalone engine self-test (no Firebase required).
 *
 * Run with:  npm run selftest    (compiles then executes node lib/selftest.js)
 *
 * Validates deck invariants, the provably-fair pipeline, the exact sample
 * scenario from the specification (Section 38), rank matching, and settlement
 * math. Exits non-zero on any failure so it can gate CI.
 */

import {
  buildCanonicalDeck,
  computeRound,
  computeReveal,
  deckHashOf,
  netProfitFor,
  payoutFor,
  shuffleDeck,
} from "./engine";
import { CardData } from "./types";
import { sha256Hex } from "./fairness";

let passed = 0;
let failed = 0;

function check(name: string, condition: boolean, detail = ""): void {
  if (condition) {
    passed += 1;
    // eslint-disable-next-line no-console
    console.log(`  ✓ ${name}`);
  } else {
    failed += 1;
    // eslint-disable-next-line no-console
    console.error(`  ✗ ${name}${detail ? ` -> ${detail}` : ""}`);
  }
}

function cardMap(): Map<string, CardData> {
  const m = new Map<string, CardData>();
  for (const c of buildCanonicalDeck()) {
    m.set(c.id, c);
  }
  return m;
}

// ---------------------------------------------------------------------------
console.log("\n[1] Deck invariants");
{
  const deck = buildCanonicalDeck();
  check("deck contains exactly 52 cards", deck.length === 52, `got ${deck.length}`);
  const ids = new Set(deck.map((c) => c.id));
  check("all 52 cards are unique", ids.size === 52, `unique=${ids.size}`);
  const suits = new Set(deck.map((c) => c.suit));
  check("exactly 4 suits present", suits.size === 4);
  for (let n = 1; n <= 13; n++) {
    const count = deck.filter((c) => c.numericRank === n).length;
    check(`rank ${n} appears exactly 4 times`, count === 4, `count=${count}`);
  }
}

// ---------------------------------------------------------------------------
console.log("\n[2] Provably-fair pipeline (determinism + commitment)");
{
  const seed = "a3f1c0de".repeat(8); // 64 hex chars, deterministic for the test
  const roundId = "round_test_0001";

  const r1 = computeRound(seed, roundId);
  const r2 = computeRound(seed, roundId);

  check("SHA256(serverSeed) === serverSeedHash", sha256Hex(seed) === r1.serverSeedHash);
  check("shuffle is deterministic (deckHash stable)", r1.deckHash === r2.deckHash, `${r1.deckHash} vs ${r2.deckHash}`);
  check("winner is deterministic", r1.winner === r2.winner);

  const shuffled = shuffleDeck(seed, roundId);
  check("shuffled deck still has 52 cards", shuffled.length === 52);
  check("shuffled deck is a permutation of canonical", new Set(shuffled.map((c) => c.id)).size === 52);

  check("target card is deck[0]", r1.targetCard.id === shuffled[0].id);
  const remaining = shuffled.slice(1);
  check("remaining deck has 51 cards", remaining.length === 51);
  check("target card removed from remaining", !remaining.some((c) => c.id === r1.targetCard.id));
  const targetRankRemaining = remaining.filter((c) => c.numericRank === r1.targetNumericRank).length;
  check("exactly 3 target-rank cards remain", targetRankRemaining === 3, `count=${targetRankRemaining}`);

  // Simulate the CLIENT independently re-deriving the outcome from the revealed
  // seed and confirming it matches the server's published hash + winner.
  const clientDeck = shuffleDeck(seed, roundId);
  check("client re-derivation reproduces deckHash", deckHashOf(clientDeck) === r1.deckHash);
  const clientOutcome = computeReveal(clientDeck.slice(1), clientDeck[0].numericRank);
  check("client re-derivation reproduces winner", clientOutcome.winner === r1.winner);
  check("winning card actually matches target rank", r1.revealSequence[r1.winningIndex].card.numericRank === r1.targetNumericRank);
  check("reveal stops at first match", r1.revealSequence.length === r1.winningIndex + 1);
  // Alternation invariant
  const alternationOk = r1.revealSequence.every((s) => s.side === (s.index % 2 === 0 ? "left" : "right"));
  check("reveal alternates LEFT(even)/RIGHT(odd)", alternationOk);
}

// ---------------------------------------------------------------------------
console.log("\n[3] Exact sample scenario (Section 38): target 7, LEFT wins");
{
  const m = cardMap();
  const remaining = [
    m.get("king_clubs")!, // LEFT  index 0
    m.get("three_hearts")!, // RIGHT index 1
    m.get("two_diamonds")!, // LEFT  index 2
    m.get("queen_spades")!, // RIGHT index 3
    m.get("seven_clubs")!, // LEFT  index 4  <-- first 7
    m.get("seven_diamonds")!, // never reached
    m.get("seven_spades")!, // never reached
  ];
  const outcome = computeReveal(remaining, 7);
  check("winner is LEFT", outcome.winner === "left", outcome.winner);
  check("winning index is 4", outcome.winningIndex === 4, `${outcome.winningIndex}`);
  check("animation stops immediately after 7♣", outcome.steps.length === 5, `${outcome.steps.length}`);
  check("winning card is 7♣", outcome.steps[outcome.winningIndex].card.id === "seven_clubs");
}

// ---------------------------------------------------------------------------
console.log("\n[4] Rank matching is by rank identity, not suit");
{
  const m = cardMap();
  // Any 7 matches a target rank of 7 regardless of suit.
  const remaining = [m.get("seven_spades")!]; // LEFT index 0
  const outcome = computeReveal(remaining, 7);
  check("7♠ matches target rank 7 on LEFT", outcome.winner === "left" && outcome.winningIndex === 0);
}

// ---------------------------------------------------------------------------
console.log("\n[5] Settlement math (multiplier 2.0)");
{
  const stake = 500;
  const mult = 2.0;
  check("winner payout = floor(stake*mult)", payoutFor(stake, "left", "left", mult) === 1000);
  check("loser payout = 0", payoutFor(stake, "right", "left", mult) === 0);
  check("winner net profit = +500", netProfitFor(stake, "left", "left", mult) === 500);
  check("loser net profit = -500", netProfitFor(stake, "right", "left", mult) === -500);
  // Fractional multiplier flooring
  check("floor applied for 1.9x", payoutFor(500, "left", "left", 1.9) === 950);
  check("floor applied for 1.95x on odd stake", payoutFor(333, "left", "left", 1.95) === 649);
}

// ---------------------------------------------------------------------------
console.log("\n[6] Distribution smoke test (no obvious bias over many seeds)");
{
  let left = 0;
  let right = 0;
  const trials = 5000;
  for (let i = 0; i < trials; i++) {
    // Distinct deterministic seeds derived from the index.
    const seed = sha256Hex(`smoke:${i}`);
    const r = computeRound(seed, `r${i}`);
    if (r.winner === "left") left++;
    else right++;
  }
  const leftPct = (left / trials) * 100;
  // LEFT reveals first, so a mild LEFT edge is expected and fair; assert it is
  // within a sane band (not degenerate) rather than exactly 50/50.
  check(
    `winner split is non-degenerate (LEFT ${leftPct.toFixed(1)}%)`,
    leftPct > 45 && leftPct < 70,
    `${left}/${right}`,
  );
}

// ---------------------------------------------------------------------------
console.log(`\nRESULT: ${passed} passed, ${failed} failed\n`);
if (failed > 0) {
  process.exit(1);
}
