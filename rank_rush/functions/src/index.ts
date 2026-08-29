/**
 * Rank Rush — Cloud Functions entrypoints (firebase-functions v2 + a v1 auth
 * trigger for provisioning). VIRTUAL COINS ONLY.
 *
 * Every callable validates authentication; admin callables additionally verify
 * a role custom-claim. Domain errors are mapped to safe, user-friendly
 * HttpsError codes/messages — stack traces are never exposed to the client.
 */

import { setGlobalOptions } from "firebase-functions/v2";
import { CallableRequest, HttpsError, onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as functionsV1 from "firebase-functions/v1";
import { getAuth } from "firebase-admin/auth";

import { db, FieldValue } from "./firestore";
import { DEFAULT_GAME_ID, ensureGameConfig, getGameConfig, sanitizeConfigPatch } from "./config";
import { placeBet, PlaceBetInput } from "./bets";
import { cancelRound, createRound, syncRound } from "./rounds";
import { appendLedger, claimDailyBonus, ensureProfile, userRef } from "./wallet";
import { computeRound } from "./engine";
import { Role, Side } from "./types";

const REGION = process.env.FUNCTIONS_REGION || "us-central1";
const ENFORCE_APP_CHECK = process.env.ENFORCE_APP_CHECK === "true";

setGlobalOptions({ region: REGION, maxInstances: 20 });

const callableOpts = { enforceAppCheck: ENFORCE_APP_CHECK, consumeAppCheckToken: false };

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function requireAuth(request: CallableRequest): string {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }
  return request.auth.uid;
}

function roleOf(request: CallableRequest): Role {
  const claim = request.auth?.token?.role;
  if (claim === "ADMIN" || claim === "SUPER_ADMIN") return claim;
  return "USER";
}

function requireRole(request: CallableRequest, allowed: Role[]): string {
  const uid = requireAuth(request);
  if (!allowed.includes(roleOf(request))) {
    throw new HttpsError("permission-denied", "Admin privileges are required.");
  }
  return uid;
}

function asString(v: unknown, field: string): string {
  if (typeof v !== "string" || v.length === 0 || v.length > 200) {
    throw new HttpsError("invalid-argument", `Invalid ${field}.`);
  }
  return v;
}

function asSide(v: unknown): Side {
  if (v !== "left" && v !== "right") {
    throw new HttpsError("invalid-argument", "Side must be 'left' or 'right'.");
  }
  return v;
}

function asInt(v: unknown, field: string): number {
  const n = Number(v);
  if (!Number.isInteger(n)) throw new HttpsError("invalid-argument", `Invalid ${field}.`);
  return n;
}

/** Maps internal domain error codes to safe client-facing HttpsError. */
function toHttpsError(e: unknown): HttpsError {
  if (e instanceof HttpsError) return e;
  const code = e instanceof Error ? e.message : "UNKNOWN";
  switch (code) {
    case "INSUFFICIENT_FUNDS":
      return new HttpsError("failed-precondition", "Insufficient virtual coins for this bet.");
    case "BETTING_CLOSED":
      return new HttpsError("failed-precondition", "Betting is closed for this round.");
    case "ALREADY_BET":
      return new HttpsError("already-exists", "You already placed a bet this round.");
    case "ALREADY_CLAIMED":
      return new HttpsError("failed-precondition", "You already claimed today's bonus.");
    case "DAILY_LIMIT":
      return new HttpsError("resource-exhausted", "Daily virtual-coin bet limit reached.");
    case "SELF_EXCLUDED":
      return new HttpsError("failed-precondition", "Gameplay is currently disabled on your account.");
    case "BELOW_MIN_BET":
    case "ABOVE_MAX_BET":
    case "INVALID_AMOUNT":
    case "INVALID_SIDE":
    case "INVALID_ARGUMENT":
      return new HttpsError("invalid-argument", "That bet is not valid.");
    case "GAME_DISABLED":
      return new HttpsError("failed-precondition", "The game is temporarily unavailable.");
    case "ROUND_NOT_FOUND":
      return new HttpsError("not-found", "Round not found.");
    case "ROUND_NOT_FINISHED":
      return new HttpsError("failed-precondition", "This round has not finished yet.");
    case "PROFILE_MISSING":
      return new HttpsError("failed-precondition", "Your profile is still being set up. Try again.");
    default:
      // Do not leak internals.
      // eslint-disable-next-line no-console
      console.error("Unhandled error:", e);
      return new HttpsError("internal", "Something went wrong. Please try again.");
  }
}

// ---------------------------------------------------------------------------
// Player callables
// ---------------------------------------------------------------------------

/** Idempotently provisions the caller's profile. Called right after sign-in. */
export const ensureProfileFn = onCall(callableOpts, async (request) => {
  const uid = requireAuth(request);
  const requestedName = typeof request.data?.displayName === "string" ? request.data.displayName : null;
  try {
    const profile = await ensureProfile(uid, requestedName);
    return { ok: true, profile: { uid: profile.uid, displayName: profile.displayName } };
  } catch (e) {
    throw toHttpsError(e);
  }
});

/** Advances the shared game (create/settle/next). Safe to call periodically. */
export const syncRoundFn = onCall(callableOpts, async (request) => {
  requireAuth(request);
  const gameId = typeof request.data?.gameId === "string" ? request.data.gameId : DEFAULT_GAME_ID;
  try {
    await syncRound(gameId);
    return { ok: true };
  } catch (e) {
    throw toHttpsError(e);
  }
});

/** Places a virtual-coin bet on the current round. */
export const placeBetFn = onCall(callableOpts, async (request) => {
  const uid = requireAuth(request);
  const data = request.data ?? {};
  const input: PlaceBetInput = {
    gameId: typeof data.gameId === "string" ? data.gameId : DEFAULT_GAME_ID,
    roundId: asString(data.roundId, "roundId"),
    betId: asString(data.betId, "betId"),
    side: asSide(data.side),
    stake: asInt(data.stake, "stake"),
  };
  try {
    return await placeBet(uid, input);
  } catch (e) {
    throw toHttpsError(e);
  }
});

/** Claims the daily virtual-coin bonus (one per UTC day). */
export const claimDailyBonusFn = onCall(callableOpts, async (request) => {
  const uid = requireAuth(request);
  try {
    return await claimDailyBonus(uid);
  } catch (e) {
    throw toHttpsError(e);
  }
});

/**
 * Server-side fairness re-verification for a finished round. The client also
 * verifies locally in Dart; this is a convenience/second opinion.
 */
export const verifyFairnessFn = onCall(callableOpts, async (request) => {
  requireAuth(request);
  const data = request.data ?? {};
  const gameId = typeof data.gameId === "string" ? data.gameId : DEFAULT_GAME_ID;
  const roundId = asString(data.roundId, "roundId");
  try {
    const snap = await db.doc(`games/${gameId}/rounds/${roundId}`).get();
    if (!snap.exists) throw new Error("ROUND_NOT_FOUND");
    const round = snap.data() as {
      status: string;
      serverSeed: string | null;
      serverSeedHash: string;
      deckHash: string | null;
      winner: string | null;
    };
    if (!round.serverSeed) throw new Error("ROUND_NOT_FINISHED");
    const comp = computeRound(round.serverSeed, roundId);
    const valid =
      comp.serverSeedHash === round.serverSeedHash &&
      comp.deckHash === round.deckHash &&
      comp.winner === round.winner;
    return {
      valid,
      recomputed: {
        serverSeedHash: comp.serverSeedHash,
        deckHash: comp.deckHash,
        winner: comp.winner,
        targetCard: comp.targetCard.code,
      },
    };
  } catch (e) {
    throw toHttpsError(e);
  }
});

/** Returns authoritative server time (for client countdown calibration). */
export const serverTimeFn = onCall(callableOpts, async (request) => {
  requireAuth(request);
  return { now: Date.now() };
});

/** Responsible-play: caller self-excludes from gameplay for N hours. */
export const selfExcludeFn = onCall(callableOpts, async (request) => {
  const uid = requireAuth(request);
  const hours = Math.max(1, Math.min(24 * 30, asInt(request.data?.hours ?? 24, "hours")));
  const until = Date.now() + hours * 3600_000;
  await userRef(uid).update({ selfExcludedUntil: until });
  return { ok: true, selfExcludedUntil: until };
});

// ---------------------------------------------------------------------------
// Admin callables (role-gated)
// ---------------------------------------------------------------------------

export const adminCreateRoundFn = onCall(callableOpts, async (request) => {
  requireRole(request, ["ADMIN", "SUPER_ADMIN"]);
  const gameId = typeof request.data?.gameId === "string" ? request.data.gameId : DEFAULT_GAME_ID;
  try {
    const roundId = await createRound(gameId);
    return { ok: true, roundId };
  } catch (e) {
    throw toHttpsError(e);
  }
});

export const adminCancelRoundFn = onCall(callableOpts, async (request) => {
  requireRole(request, ["ADMIN", "SUPER_ADMIN"]);
  const gameId = typeof request.data?.gameId === "string" ? request.data.gameId : DEFAULT_GAME_ID;
  const roundId = asString(request.data?.roundId, "roundId");
  try {
    await cancelRound(gameId, roundId);
    return { ok: true };
  } catch (e) {
    throw toHttpsError(e);
  }
});

export const adminSetConfigFn = onCall(callableOpts, async (request) => {
  requireRole(request, ["ADMIN", "SUPER_ADMIN"]);
  try {
    const patch = sanitizeConfigPatch(request.data?.config);
    await db.doc("config/game").set(patch, { merge: true });
    return { ok: true, config: await getGameConfig() };
  } catch (e) {
    throw toHttpsError(e);
  }
});

export const adminAdjustBalanceFn = onCall(callableOpts, async (request) => {
  requireRole(request, ["ADMIN", "SUPER_ADMIN"]);
  const targetUid = asString(request.data?.uid, "uid");
  const delta = asInt(request.data?.delta, "delta");
  const reason = typeof request.data?.reason === "string" ? request.data.reason.slice(0, 140) : "admin";
  try {
    const result = await db.runTransaction(async (tx) => {
      const uRef = userRef(targetUid);
      const uSnap = await tx.get(uRef);
      if (!uSnap.exists) throw new Error("PROFILE_MISSING");
      const balanceBefore = (uSnap.data() as { virtualCoinBalance: number }).virtualCoinBalance;
      const balanceAfter = Math.max(0, balanceBefore + delta);
      tx.update(uRef, { virtualCoinBalance: balanceAfter, lastActiveAt: FieldValue.serverTimestamp() });
      appendLedger(tx, targetUid, {
        type: "ADMIN_ADJUSTMENT",
        amount: balanceAfter - balanceBefore,
        balanceBefore,
        balanceAfter,
        referenceId: reason,
      });
      return { balanceBefore, balanceAfter };
    });
    return { ok: true, ...result };
  } catch (e) {
    throw toHttpsError(e);
  }
});

/** SUPER_ADMIN only: grants/revokes an admin role via custom claims. */
export const adminSetRoleFn = onCall(callableOpts, async (request) => {
  requireRole(request, ["SUPER_ADMIN"]);
  const targetUid = asString(request.data?.uid, "uid");
  const role = request.data?.role;
  if (role !== "USER" && role !== "ADMIN" && role !== "SUPER_ADMIN") {
    throw new HttpsError("invalid-argument", "Invalid role.");
  }
  await getAuth().setCustomUserClaims(targetUid, { role });
  await userRef(targetUid).set({ role }, { merge: true });
  return { ok: true };
});

export const adminSuspendUserFn = onCall(callableOpts, async (request) => {
  requireRole(request, ["ADMIN", "SUPER_ADMIN"]);
  const targetUid = asString(request.data?.uid, "uid");
  const suspended = Boolean(request.data?.suspended);
  await getAuth().updateUser(targetUid, { disabled: suspended });
  await userRef(targetUid).set({ suspended }, { merge: true });
  return { ok: true, suspended };
});

// ---------------------------------------------------------------------------
// Scheduled backstop + auth provisioning
// ---------------------------------------------------------------------------

/**
 * Backstop that keeps the default table advancing even if no client is polling.
 * The game is primarily driven by client `syncRound` calls; this guarantees
 * liveness. Runs every minute (Cloud Scheduler minimum granularity).
 */
export const gameLoop = onSchedule("every 1 minutes", async () => {
  await ensureGameConfig();
  await syncRound(DEFAULT_GAME_ID);
});

/** Provisions a profile on account creation (incl. anonymous/guest). */
export const provisionUser = functionsV1
  .region(REGION)
  .auth.user()
  .onCreate(async (user) => {
    await ensureProfile(user.uid, user.displayName ?? null);
  });
