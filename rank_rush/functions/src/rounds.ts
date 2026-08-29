/**
 * Authoritative round lifecycle.
 *
 * Design notes
 *  - The server commits to an outcome the instant a round is created: it
 *    generates `serverSeed`, computes the full deck/reveal/winner, and stores
 *    the seed privately while publishing only `serverSeedHash` + the target
 *    card. The outcome cannot change afterwards.
 *  - At/after `bettingClosesAt`, settlement publishes the seed + reveal
 *    sequence + winner and atomically pays out all bets. The Flutter client
 *    only animates the already-decided sequence (Section 50).
 *  - Every state transition is guarded by the current status + server time and
 *    is idempotent, so it is safe to drive from client `syncRound` pings and/or
 *    a scheduled backstop, and safe to retry after a crash.
 */

import { Timestamp } from "firebase-admin/firestore";
import { db, FieldValue, newId } from "./firestore";
import { ensureGameConfig } from "./config";
import { computeRound } from "./engine";
import { generateServerSeed } from "./fairness";
import { CardData, GameStatus, RevealStep } from "./types";
import { appendLedger, userRef, weekKeyOf } from "./wallet";

/** How long a finished round lingers (for the result screen) before the next opens. */
const RESULT_LINGER_MS = 4000;

function cardToMap(c: CardData): Record<string, unknown> {
  return { id: c.id, suit: c.suit, rank: c.rank, numericRank: c.numericRank, code: c.code };
}

function stepToMap(s: RevealStep): Record<string, unknown> {
  return { index: s.index, side: s.side, card: cardToMap(s.card) };
}

function roundRefOf(gameId: string, roundId: string) {
  return db.doc(`games/${gameId}/rounds/${roundId}`);
}
function secretRefOf(gameId: string, roundId: string) {
  return db.doc(`games/${gameId}/rounds/${roundId}/private/secret`);
}
function gameRefOf(gameId: string) {
  return db.doc(`games/${gameId}`);
}

/**
 * Creates a new betting round if there is no active round. Returns the roundId
 * (existing active one if creation was skipped).
 */
export async function createRound(gameId: string): Promise<string> {
  const config = await ensureGameConfig();
  if (!config.enabled) {
    throw new Error("GAME_DISABLED");
  }
  const roundId = newId("rnd_");
  const serverSeed = generateServerSeed();
  const comp = computeRound(serverSeed, roundId);
  const now = Timestamp.now();
  const bettingClosesAt = Timestamp.fromMillis(now.toMillis() + config.roundDurationMs);

  const created = await db.runTransaction(async (tx) => {
    const gameSnap = await tx.get(gameRefOf(gameId));
    const currentId = gameSnap.exists
      ? ((gameSnap.data() as { currentRoundId?: string }).currentRoundId ?? null)
      : null;
    if (currentId) {
      const curSnap = await tx.get(roundRefOf(gameId, currentId));
      if (curSnap.exists) {
        const st = (curSnap.data() as { status: GameStatus }).status;
        if (st === "betting" || st === "locked" || st === "revealing") {
          return currentId; // active round exists; do not create another
        }
      }
    }
    tx.set(roundRefOf(gameId, roundId), {
      id: roundId,
      gameId,
      status: "betting" as GameStatus,
      serverSeedHash: comp.serverSeedHash,
      targetCard: cardToMap(comp.targetCard),
      targetRank: comp.targetRank,
      targetNumericRank: comp.targetNumericRank,
      payoutMultiplier: config.payoutMultiplier,
      minBet: config.minBet,
      maxBet: config.maxBet,
      revealIntervalMs: config.revealIntervalMs,
      roundDurationMs: config.roundDurationMs,
      playerCount: 0,
      leftPlayers: 0,
      rightPlayers: 0,
      leftStake: 0,
      rightStake: 0,
      // Revealed only at settlement:
      serverSeed: null,
      deckHash: null,
      revealSequence: null,
      winner: null,
      winningIndex: null,
      revealStartedAt: null,
      revealDurationMs: null,
      completedAt: null,
      createdAt: FieldValue.serverTimestamp(),
      bettingClosesAt,
    });
    tx.set(secretRefOf(gameId, roundId), {
      serverSeed,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.set(
      gameRefOf(gameId),
      { gameId, currentRoundId: roundId, updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
    return roundId;
  });

  return created;
}

/**
 * Settles a round whose betting window has elapsed: publishes the authoritative
 * outcome (Phase A), pays out every bet atomically (Phase B), then marks the
 * round finished (Phase C). Idempotent and resumable.
 */
export async function settleRound(gameId: string, roundId: string): Promise<void> {
  const roundRef = roundRefOf(gameId, roundId);
  const secretRef = secretRefOf(gameId, roundId);

  // Phase A: betting -> revealing (publish seed, reveal sequence, winner).
  await db.runTransaction(async (tx) => {
    const rSnap = await tx.get(roundRef);
    if (!rSnap.exists) throw new Error("ROUND_NOT_FOUND");
    const data = rSnap.data() as {
      status: GameStatus;
      bettingClosesAt: Timestamp;
      revealIntervalMs: number;
    };
    if (data.status !== "betting") return; // another worker already advanced it
    if (Timestamp.now().toMillis() < data.bettingClosesAt.toMillis()) return; // not yet
    const secSnap = await tx.get(secretRef);
    if (!secSnap.exists) throw new Error("SECRET_MISSING");
    const serverSeed = (secSnap.data() as { serverSeed: string }).serverSeed;
    const comp = computeRound(serverSeed, roundId);
    const revealDurationMs = comp.revealSequence.length * data.revealIntervalMs;
    tx.update(roundRef, {
      status: "revealing" as GameStatus,
      serverSeed,
      deckHash: comp.deckHash,
      revealSequence: comp.revealSequence.map(stepToMap),
      winner: comp.winner,
      winningIndex: comp.winningIndex,
      revealDurationMs,
      revealStartedAt: FieldValue.serverTimestamp(),
      completedAt: FieldValue.serverTimestamp(),
    });
  });

  // Phase B: settle each placed bet (idempotent per bet).
  await settleBets(gameId, roundId);

  // Phase C: revealing -> finished.
  await db.runTransaction(async (tx) => {
    const rSnap = await tx.get(roundRef);
    if (!rSnap.exists) return;
    if ((rSnap.data() as { status: GameStatus }).status === "revealing") {
      tx.update(roundRef, { status: "finished" as GameStatus });
    }
  });
}

/** Atomically settles all placed bets against the round's published winner. */
async function settleBets(gameId: string, roundId: string): Promise<void> {
  const roundRef = roundRefOf(gameId, roundId);
  const rSnap = await roundRef.get();
  if (!rSnap.exists) return;
  const round = rSnap.data() as {
    winner: "left" | "right";
    payoutMultiplier: number;
    targetCard: Record<string, unknown>;
    targetRank: string;
  };
  if (!round.winner) return;

  const currentWeek = weekKeyOf(new Date());
  const betsSnap = await db
    .collection(`games/${gameId}/rounds/${roundId}/bets`)
    .where("status", "==", "placed")
    .get();

  for (const betDoc of betsSnap.docs) {
    // Each bet settled in its own transaction to bound contention and allow
    // safe resumption if the function is interrupted mid-batch.
    // eslint-disable-next-line no-await-in-loop
    await db.runTransaction(async (tx) => {
      const bRef = betDoc.ref;
      const bSnap = await tx.get(bRef);
      if (!bSnap.exists) return;
      const bet = bSnap.data() as {
        uid: string;
        betId: string;
        side: "left" | "right";
        stake: number;
        status: string;
      };
      if (bet.status !== "placed") return; // already settled

      const uRef = userRef(bet.uid);
      const lbRef = db.doc(`leaderboardEntries/${bet.uid}`);
      const [uSnap, lbSnap] = await Promise.all([tx.get(uRef), tx.get(lbRef)]);

      const won = bet.side === round.winner;
      const payout = won ? Math.floor(bet.stake * round.payoutMultiplier) : 0;
      const net = payout - bet.stake;

      if (uSnap.exists) {
        const balanceBefore = (uSnap.data() as { virtualCoinBalance: number }).virtualCoinBalance;
        const balanceAfter = balanceBefore + payout; // stake already debited at bet time
        tx.update(uRef, {
          virtualCoinBalance: balanceAfter,
          totalGames: FieldValue.increment(1),
          totalWins: FieldValue.increment(won ? 1 : 0),
          totalLosses: FieldValue.increment(won ? 0 : 1),
          lastActiveAt: FieldValue.serverTimestamp(),
        });
        appendLedger(tx, bet.uid, {
          type: won ? "WIN" : "LOSS",
          amount: payout, // WIN credits payout; LOSS records 0 (stake already debited)
          balanceBefore,
          balanceAfter,
          roundId,
          referenceId: bet.betId,
        });
        // Weekly leaderboard with week rollover.
        const lb = lbSnap.exists ? (lbSnap.data() as Record<string, unknown>) : {};
        const sameWeek = lb.weekKey === currentWeek;
        const weeklyWins = (sameWeek ? Number(lb.weeklyWins ?? 0) : 0) + (won ? 1 : 0);
        tx.set(
          lbRef,
          {
            virtualCoinBalance: balanceAfter,
            totalWins: FieldValue.increment(won ? 1 : 0),
            gamesPlayed: FieldValue.increment(1),
            weeklyWins,
            weekKey: currentWeek,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }

      tx.update(bRef, {
        status: "settled",
        payout,
        netProfit: net,
        settledAt: FieldValue.serverTimestamp(),
      });

      // Per-user game history entry.
      tx.set(db.doc(`users/${bet.uid}/gameHistory/${roundId}`), {
        roundId,
        gameId,
        targetCard: round.targetCard,
        targetRank: round.targetRank,
        side: bet.side,
        stake: bet.stake,
        winner: round.winner,
        won,
        payout,
        netProfit: net,
        completedAt: FieldValue.serverTimestamp(),
      });
    });
  }
}

/**
 * Ensures the game keeps running: settles an expired round, opens the next one
 * after a short result-linger, or creates the first round. Idempotent; safe to
 * call from any authenticated client and from the scheduled backstop.
 */
export async function syncRound(gameId: string): Promise<void> {
  await ensureGameConfig();
  const gameSnap = await gameRefOf(gameId).get();
  const currentId = gameSnap.exists
    ? ((gameSnap.data() as { currentRoundId?: string }).currentRoundId ?? null)
    : null;

  if (!currentId) {
    await createRound(gameId);
    return;
  }

  const rSnap = await roundRefOf(gameId, currentId).get();
  if (!rSnap.exists) {
    await createRound(gameId);
    return;
  }
  const round = rSnap.data() as {
    status: GameStatus;
    bettingClosesAt: Timestamp;
    completedAt: Timestamp | null;
    revealDurationMs: number | null;
  };
  const nowMs = Date.now();

  if (round.status === "betting" && nowMs >= round.bettingClosesAt.toMillis()) {
    await settleRound(gameId, currentId);
    return;
  }

  if (round.status === "revealing") {
    // Finish settlement if it was interrupted, then let it linger.
    await settleRound(gameId, currentId);
    return;
  }

  if (round.status === "finished" || round.status === "cancelled") {
    const completedMs = round.completedAt ? round.completedAt.toMillis() : 0;
    const revealMs = round.revealDurationMs ?? 0;
    if (nowMs >= completedMs + revealMs + RESULT_LINGER_MS) {
      await createRound(gameId);
    }
  }
}

/** Admin: cancels a round and refunds all placed bets. */
export async function cancelRound(gameId: string, roundId: string): Promise<void> {
  const roundRef = roundRefOf(gameId, roundId);
  const betsSnap = await db
    .collection(`games/${gameId}/rounds/${roundId}/bets`)
    .where("status", "==", "placed")
    .get();

  for (const betDoc of betsSnap.docs) {
    // eslint-disable-next-line no-await-in-loop
    await db.runTransaction(async (tx) => {
      const bSnap = await tx.get(betDoc.ref);
      if (!bSnap.exists) return;
      const bet = bSnap.data() as { uid: string; betId: string; stake: number; status: string };
      if (bet.status !== "placed") return;
      const uRef = userRef(bet.uid);
      const uSnap = await tx.get(uRef);
      if (uSnap.exists) {
        const balanceBefore = (uSnap.data() as { virtualCoinBalance: number }).virtualCoinBalance;
        const balanceAfter = balanceBefore + bet.stake;
        tx.update(uRef, {
          virtualCoinBalance: balanceAfter,
          lastActiveAt: FieldValue.serverTimestamp(),
        });
        appendLedger(tx, bet.uid, {
          type: "REFUND",
          amount: bet.stake,
          balanceBefore,
          balanceAfter,
          roundId,
          referenceId: bet.betId,
        });
      }
      tx.update(betDoc.ref, { status: "refunded", settledAt: FieldValue.serverTimestamp() });
    });
  }

  await roundRef.update({
    status: "cancelled" as GameStatus,
    completedAt: FieldValue.serverTimestamp(),
  });
}
