# Rank Rush — Provable Fairness Specification

> **Virtual coins only.** Rank Rush is an entertainment game. The "coins" have
> no monetary value and cannot be bought, sold, withdrawn, or exchanged for
> anything of value. This document explains how a player can mathematically
> verify that the **server did not cheat** — not how to win money, because there
> is none to win.

This is the authoritative, byte-level specification of the deterministic game
engine. It is implemented three times and they **must** agree exactly:

| Where | File | Role |
|-------|------|------|
| Server (authoritative) | `functions/src/fairness.ts`, `functions/src/engine.ts` | Runs the real round |
| Client (verifier) | `lib/core/security/provably_fair.dart` | Independently rebuilds a finished round on-device |
| Test vector | `test/engine/provably_fair_test.dart` | Locks the spec with a fixed input→output example |

If you change any step below, you must update **all three** or the client's
verification screen will (correctly) report a mismatch.

---

## 1. The commitment scheme

The design goal: the server must **commit to the entire outcome before any bets
are placed**, then **prove after the round** that it did not alter anything.

1. **Before a round opens**, the server generates a cryptographically random
   32-byte `serverSeed` (64 lowercase hex chars) and publishes only its hash:

   ```
   serverSeedHash = SHA256_hex( serverSeed )
   ```

   The raw `serverSeed` is stored in a `private/secret` document that **no client
   can ever read** (enforced by Firestore rules: `allow read, write: if false`).

2. The **entire deck order** is derived deterministically from
   `(serverSeed, roundId)`. The target card and winner are therefore fixed the
   moment the seed exists — before anyone bets.

3. **After the round settles**, the server reveals `serverSeed` on the public
   round document. Anyone can now:
   - confirm `SHA256(serverSeed) == serverSeedHash` (the pre-round commitment), and
   - re-run the algorithm below to reproduce the deck, target card, and winner,
     and confirm they match what the server reported.

Because SHA-256 is preimage- and collision-resistant, the server cannot have
picked the seed *after* seeing the bets to force a particular winner: it was
bound to `serverSeedHash` before betting opened.

---

## 2. Primitive: `sha256Hex(input)`

Hex-encoded SHA-256 of the **UTF-8** bytes of `input`, lowercase.

- TS: `createHash("sha256").update(input, "utf8").digest("hex")`
- Dart: `sha256.convert(utf8.encode(input)).toString()`

Sanity check (the empty string):

```
sha256Hex("") = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```

---

## 3. Primitive: `SeededRng(serverSeed, roundId)`

A deterministic PRNG whose only entropy source is SHA-256.

**Byte stream.** For `k = 0, 1, 2, …` produce 32-byte blocks:

```
block(k) = SHA256_bytes( UTF8( "{serverSeed}:{roundId}:{k}" ) )
```

The blocks are concatenated and consumed **4 bytes at a time**, interpreted as a
**big-endian unsigned 32-bit integer** (`nextUint32`). Because each block is
exactly 32 bytes (a multiple of 4), reads never straddle a block boundary in a
way that could diverge between implementations.

**Unbiased `nextInt(n)`** — uniform integer in `[0, n)` for `1 ≤ n ≤ 2³²`:

```
if n == 1: return 0
limit = floor(2^32 / n) * n        // largest multiple of n that is < 2^32
x = nextUint32()
while x >= limit: x = nextUint32()  // rejection sampling removes modulo bias
return x % n
```

The rejection step is what makes the shuffle provably uniform: naive
`nextUint32() % n` would very slightly favour smaller results.

---

## 4. The canonical (unshuffled) deck

52 cards, built in a fixed order so both sides start identically.

- **Suit order:** `hearts, diamonds, clubs, spades`
- **Rank order (ace-low):** `ace(1), two(2), … , ten(10), jack(11), queen(12), king(13)`
- **Index formula:** `index = suitIndex * 13 + (numericRank - 1)`
- **Card id:** `"{rankName}_{suit}"` — e.g. `seven_hearts`
- **Card code:** `"{rankCode}{suitCode}"` where suit codes are `H D C S` and rank
  codes are `A 2 3 4 5 6 7 8 9 10 J Q K` — e.g. `7H`, `10D`, `AS`

So `deck[0]` is `AH` (ace of hearts) and `deck[51]` is `KS` (king of spades).

---

## 5. Deterministic shuffle (seeded Fisher–Yates)

```
deck = buildCanonicalDeck()          // 52 cards
rng  = SeededRng(serverSeed, roundId)
for i = 51 down to 1:
    j = rng.nextInt(i + 1)           // 0 .. i inclusive
    swap(deck[i], deck[j])
return deck
```

The loop runs high→low and draws `j` inclusive of `i`; this exact ordering is
part of the spec because a different iteration direction produces a different
permutation from the same random stream.

**Deck hash** (order-sensitive), published so the shuffle can be checked in one
comparison:

```
deckHash = sha256Hex( deck.map(card => card.id).join(",") )
```

---

## 6. Target card, reveal, and winner

```
deck        = shuffleDeck(serverSeed, roundId)
targetCard  = deck[0]                       // its rank is the "target rank"
remaining   = deck[1 .. 51]                 // 51 cards, target removed
```

Walk `remaining` from index 0, alternating sides, and **stop at the first card
whose rank equals the target rank**:

```
for i = 0, 1, 2, …:
    side = (i is even) ? LEFT : RIGHT       // LEFT owns even indices
    if remaining[i].numericRank == targetCard.numericRank:
        winner       = side
        winningIndex = i
        break
```

Matching is by **rank only**, ignoring suit. After the target is removed, exactly
**3** of the target rank's 4 cards remain, so a match is always found — the round
can never end without a winner.

> **Note on the LEFT edge.** Because LEFT is revealed first at each pair of
> positions, LEFT wins slightly more than 50% of rounds. This is a fixed,
> transparent property of the rules (not a hidden bias), and the client verifier
> confirms the winner independently regardless.

---

## 7. Settlement math (virtual coins)

When a bet is placed, its `stake` is debited immediately. At settlement:

```
payout    = (side == winner) ? floor(stake * payoutMultiplier) : 0
netProfit = payout - stake
```

All amounts are integers; `floor` is applied after multiplying. Every balance
change is written to an **append-only ledger** (`users/{uid}/transactions`) that
clients can read but never write.

---

## 8. Canonical cross-language test vector

These fixed inputs pin the entire spec. All three implementations (and the
independent verifier in CI) must reproduce them exactly.

```
serverSeed = a1b2c3d4e5f60718293a4b5c6d7e8f90112233445566778899aabbccddeeff00
roundId    = rnd_testvector_0001

serverSeedHash = 83418260fe3c7bf5063efde5c04315bab07ae31ea393e5adf84dbc7a52181eef
deckHash       = aa1cf3a9ffcf871ec0f869607dccb29290eec5346d6bee738bbf52cd31f5e74d

deck (codes, index 0 → 51):
4C 7S 8C 3H 4S AD KS 9S 8D 2H KH 10H 8S AS 9D 10D QH KD AC JS
2C JD 5S 9C 4D 8H 10S 6H QD 5D QS JH 6D 6S 2S AH KC 3D 3S JC
6C 5H 2D QC 4H 7H 7C 3C 5C 10C 9H 7D

targetCard    = 4C   (numericRank 4)
winner        = RIGHT
winningIndex  = 3
reveal length = 4

reveal sequence (remaining = deck[1..]):
  index 0  7S  LEFT
  index 1  8C  RIGHT
  index 2  3H  LEFT
  index 3  4S  RIGHT   <-- first card of target rank 4 → RIGHT wins
```

The first card matching the target rank **4** is `4S` at index **3**, which is an
odd index → **RIGHT** wins after 4 cards are shown.

---

## 9. How to verify a round yourself

**In the app.** Open a finished round → *Provable fairness*. The screen rebuilds
the round entirely on your device (zero server calls) and shows a green check for
each of: seed→hash commitment, deck hash, target card, and winner. You can also
paste any round's revealed `serverSeed` + `roundId` into *Verify manually*.

**From a terminal.** Reproduce the test vector with nothing but Node's built-in
`crypto` (the algorithm is small enough to re-type from Section 2–6). If your
independent implementation prints `deckHash = aa1cf3a9…` and `winner = RIGHT`,
you have confirmed the spec end-to-end.

---

## 10. What this does and does not prove

**Proves:** the server committed to the deck before betting and did not change
the deck, target, or winner afterwards; the shuffle is uniform (unbiased); the
outcome is a pure, reproducible function of `(serverSeed, roundId)`.

**Does not claim:** that you can win money (you cannot — the coins are virtual),
that outcomes are predictable (the seed is secret until reveal), or that the
LEFT-first edge is hidden (it is documented above and independently verifiable).
