/**
 * placeBet — the only path by which a virtual-coin stake is committed.
 *
 * Guarantees (all enforced server-side, never trusting the client):
 *  - authenticated user with a provisioned profile
 *  - round exists and is still in `betting` before `bettingClosesAt`
 *  - stake is an integer within [minBet, maxBet] and <= balance
 *  - one bet per user per round; duplicate `betId` is idempotent
 *  - responsible-play: self-exclusion + per-day stake cap
 *  - stake debited and BET ledger entry written atomically
 */

import { Timestamp } from "firebase-admin/firestore";
import { db, FieldValue, utcDayKey } from "./firestore";
import { getGameConfig } from "./config";
import { appendLedger, userRef } from "./wallet";
import { GameStatus, Side } from "./types";

export interface PlaceBetInput {
  gameId: string;
  roundId: string;
  betId: string; // client-generated idempotency key
  side: Side;
  stake: number;
}

export interface PlaceBetResult {
  betId: string;
  status: string;
  stake: number;
  side: Side;
  newBalance: number;
}

export async function placeBet(uid: string, input: PlaceBetInput): Promise<PlaceBetResult> {
  const { gameId, roundId, betId, side, stake } = input;

  if (!gameId || !roundId || !betId) throw new Error("INVALID_ARGUMENT");
  if (side !== "left" && side !== "right") throw new Error("INVALID_SIDE");
  if (!Number.isInteger(stake) || stake <= 0) throw new Error("INVALID_AMOUNT");

  const config = await getGameConfig();
  if (!config.enabled) throw new Error("GAME_DISABLED");
  if (stake < config.minBet) throw new Error("BELOW_MIN_BET");
  if (stake > config.maxBet) throw new Error("ABOVE_MAX_BET");

  const roundRef = db.doc(`games/${gameId}/rounds/${roundId}`);
  const betRef = db.doc(`games/${gameId}/rounds/${roundId}/bets/${betId}`);
  const playerRef = db.doc(`games/${gameId}/rounds/${roundId}/players/${uid}`);
  const uRef = userRef(uid);
  const today = utcDayKey();

  return db.runTransaction(async (tx) => {
    const [rSnap, bSnap, pSnap, uSnap] = await Promise.all([
      tx.get(roundRef),
      tx.get(betRef),
      tx.get(playerRef),
      tx.get(uRef),
    ]);
    if (!rSnap.exists) throw new Error("ROUND_NOT_FOUND");
    if (!uSnap.exists) throw new Error("PROFILE_MISSING");

    const user = uSnap.data() as {
      virtualCoinBalance: number;
      displayName: string;
      avatar: string;
      dailyBetTotal?: number;
      dailyBetDate?: string;
      selfExcludedUntil?: number | null;
    };

    // Idempotency: a retry with the same betId returns the existing bet.
    if (bSnap.exists) {
      const b = bSnap.data() as { status: string; stake: number; side: Side };
      return {
        betId,
        status: b.status,
        stake: b.stake,
        side: b.side,
        newBalance: user.virtualCoinBalance,
      };
    }

    const round = rSnap.data() as { status: GameStatus; bettingClosesAt: Timestamp };
    if (round.status !== "betting") throw new Error("BETTING_CLOSED");
    if (Timestamp.now().toMillis() >= round.bettingClosesAt.toMillis()) {
      throw new Error("BETTING_CLOSED");
    }

    // One bet per user per round.
    if (pSnap.exists) throw new Error("ALREADY_BET");

    // Responsible-play checks.
    if (user.selfExcludedUntil && Date.now() < user.selfExcludedUntil) {
      throw new Error("SELF_EXCLUDED");
    }
    const dailyTotal = user.dailyBetDate === today ? (user.dailyBetTotal ?? 0) : 0;
    if (dailyTotal + stake > config.maxDailyBetPerUser) throw new Error("DAILY_LIMIT");

    if (user.virtualCoinBalance < stake) throw new Error("INSUFFICIENT_FUNDS");

    const balanceBefore = user.virtualCoinBalance;
    const balanceAfter = balanceBefore - stake;

    tx.set(betRef, {
      betId,
      uid,
      roundId,
      gameId,
      side,
      stake,
      status: "placed",
      payout: 0,
      netProfit: 0,
      displayName: user.displayName,
      avatar: user.avatar,
      createdAt: FieldValue.serverTimestamp(),
      settledAt: null,
    });
    tx.set(playerRef, {
      uid,
      side,
      stake,
      betId,
      displayName: user.displayName,
      avatar: user.avatar,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.update(uRef, {
      virtualCoinBalance: balanceAfter,
      dailyBetTotal: dailyTotal + stake,
      dailyBetDate: today,
      lastActiveAt: FieldValue.serverTimestamp(),
    });
    appendLedger(tx, uid, {
      type: "BET",
      amount: -stake,
      balanceBefore,
      balanceAfter,
      roundId,
      referenceId: betId,
    });
    tx.update(roundRef, {
      playerCount: FieldValue.increment(1),
      leftPlayers: FieldValue.increment(side === "left" ? 1 : 0),
      rightPlayers: FieldValue.increment(side === "right" ? 1 : 0),
      leftStake: FieldValue.increment(side === "left" ? stake : 0),
      rightStake: FieldValue.increment(side === "right" ? stake : 0),
    });

    return { betId, status: "placed", stake, side, newBalance: balanceAfter };
  });
}
