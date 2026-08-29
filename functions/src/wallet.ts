/**
 * Wallet ledger, user provisioning, and daily-bonus logic.
 *
 * INVARIANTS
 *  - Every balance change writes an immutable ledger entry
 *    (users/{uid}/transactions/{transactionId}) with balanceBefore/After.
 *  - Balances are only ever mutated inside Firestore transactions.
 *  - VIRTUAL COINS ONLY — there is no cash-in / cash-out anywhere.
 */

import {
  DocumentReference,
  FieldValue,
  Transaction,
} from "firebase-admin/firestore";
import { db, newId, utcDayKey } from "./firestore";
import { DEFAULT_CONFIG, STARTING_BALANCE, getGameConfig } from "./config";
import { Role, TransactionType } from "./types";

export interface UserProfile {
  uid: string;
  username: string;
  displayName: string;
  avatar: string;
  virtualCoinBalance: number;
  totalGames: number;
  totalWins: number;
  totalLosses: number;
  role: Role;
  dailyBetTotal: number;
  dailyBetDate: string;
  selfExcludedUntil: number | null;
}

/** Deterministic, privacy-safe avatar bucket derived from the uid. */
export function avatarFor(uid: string): string {
  let sum = 0;
  for (let i = 0; i < uid.length; i++) sum = (sum + uid.charCodeAt(i)) % 100000;
  return `av_${sum % 12}`;
}

/** Deterministic, privacy-safe display name (never leaks email/PII). */
export function displayNameFor(uid: string, requested?: string | null): string {
  const cleaned = (requested ?? "").trim().replace(/[^\p{L}\p{N}_ -]/gu, "").slice(0, 18);
  if (cleaned.length >= 3) return cleaned;
  const suffix = uid.slice(-4).toUpperCase();
  return `Player-${suffix}`;
}

export function userRef(uid: string): DocumentReference {
  return db.doc(`users/${uid}`);
}

/**
 * Appends an immutable ledger entry inside an existing transaction.
 * Returns the generated transactionId.
 */
export function appendLedger(
  tx: Transaction,
  uid: string,
  entry: {
    type: TransactionType;
    amount: number; // signed delta applied to the balance
    balanceBefore: number;
    balanceAfter: number;
    roundId?: string | null;
    referenceId?: string | null;
  },
): string {
  const transactionId = newId("txn_");
  const ref = db.doc(`users/${uid}/transactions/${transactionId}`);
  tx.set(ref, {
    transactionId,
    userId: uid,
    roundId: entry.roundId ?? null,
    type: entry.type,
    amount: entry.amount,
    balanceBefore: entry.balanceBefore,
    balanceAfter: entry.balanceAfter,
    status: "completed",
    referenceId: entry.referenceId ?? null,
    timestamp: FieldValue.serverTimestamp(),
  });
  return transactionId;
}

/**
 * Idempotently provisions a user profile with the starting virtual balance.
 * Safe to call on every sign-in.
 */
export async function ensureProfile(
  uid: string,
  requestedName?: string | null,
): Promise<UserProfile> {
  const ref = userRef(uid);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists) {
      tx.update(ref, { lastActiveAt: FieldValue.serverTimestamp() });
      return;
    }
    const displayName = displayNameFor(uid, requestedName);
    tx.set(ref, {
      uid,
      username: displayName,
      displayName,
      avatar: avatarFor(uid),
      virtualCoinBalance: STARTING_BALANCE,
      totalGames: 0,
      totalWins: 0,
      totalLosses: 0,
      role: "USER" as Role,
      dailyBetTotal: 0,
      dailyBetDate: utcDayKey(),
      selfExcludedUntil: null,
      createdAt: FieldValue.serverTimestamp(),
      lastActiveAt: FieldValue.serverTimestamp(),
    });
    // Audit the initial grant as a BONUS ledger entry.
    appendLedger(tx, uid, {
      type: "BONUS",
      amount: STARTING_BALANCE,
      balanceBefore: 0,
      balanceAfter: STARTING_BALANCE,
      referenceId: "welcome_grant",
    });
    // Seed a public, privacy-safe leaderboard entry.
    tx.set(db.doc(`leaderboardEntries/${uid}`), {
      uid,
      displayName,
      avatar: avatarFor(uid),
      virtualCoinBalance: STARTING_BALANCE,
      totalWins: 0,
      gamesPlayed: 0,
      weeklyWins: 0,
      weekKey: weekKeyOf(new Date()),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  const fresh = await ref.get();
  return fresh.data() as UserProfile;
}

/** ISO week key like "2026-W35" for weekly leaderboard bucketing. */
export function weekKeyOf(date: Date): string {
  const d = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  const dayNum = (d.getUTCDay() + 6) % 7; // Monday=0
  d.setUTCDate(d.getUTCDate() - dayNum + 3); // nearest Thursday
  const firstThursday = new Date(Date.UTC(d.getUTCFullYear(), 0, 4));
  const week =
    1 +
    Math.round(
      ((d.getTime() - firstThursday.getTime()) / 86400000 - 3 + ((firstThursday.getUTCDay() + 6) % 7)) / 7,
    );
  return `${d.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
}

export interface DailyBonusResult {
  amount: number;
  streak: number;
  newBalance: number;
}

/**
 * Claims the daily virtual-coin bonus. Enforces one claim per UTC day and
 * advances/resets a 7-day streak. Fully server-authoritative and idempotent
 * within a day (a second call the same day is rejected).
 */
export async function claimDailyBonus(uid: string): Promise<DailyBonusResult> {
  const config = await getGameConfig();
  const ladder = config.dailyBonusLadder.length > 0 ? config.dailyBonusLadder : DEFAULT_CONFIG.dailyBonusLadder;
  const today = utcDayKey();
  const yesterday = utcDayKey(new Date(Date.now() - 86400000));

  return db.runTransaction(async (tx) => {
    const uRef = userRef(uid);
    const rRef = db.doc(`dailyRewards/${uid}`);
    const [uSnap, rSnap] = await Promise.all([tx.get(uRef), tx.get(rRef)]);
    if (!uSnap.exists) {
      throw new Error("PROFILE_MISSING");
    }
    const reward = rSnap.exists ? (rSnap.data() as { streak: number; lastClaimDate: string }) : null;
    if (reward && reward.lastClaimDate === today) {
      throw new Error("ALREADY_CLAIMED");
    }
    const streak = reward && reward.lastClaimDate === yesterday ? reward.streak + 1 : 1;
    const amount = ladder[(streak - 1) % ladder.length];

    const balanceBefore = (uSnap.data() as UserProfile).virtualCoinBalance;
    const balanceAfter = balanceBefore + amount;

    tx.update(uRef, {
      virtualCoinBalance: balanceAfter,
      lastActiveAt: FieldValue.serverTimestamp(),
    });
    tx.set(
      rRef,
      { streak, lastClaimDate: today, lastClaimAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
    appendLedger(tx, uid, {
      type: "BONUS",
      amount,
      balanceBefore,
      balanceAfter,
      referenceId: `daily_${today}`,
    });
    tx.set(
      db.doc(`leaderboardEntries/${uid}`),
      { virtualCoinBalance: balanceAfter, updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
    return { amount, streak, newBalance: balanceAfter };
  });
}
