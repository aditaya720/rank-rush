/**
 * Server-owned game configuration and constants.
 *
 * The client NEVER supplies these values. A snapshot is copied onto each round
 * document so historical rounds remain auditable even if the config changes.
 */

import { db } from "./firestore";
import { GameConfig } from "./types";

/** Starting VIRTUAL-COIN balance granted to a new account. */
export const STARTING_BALANCE = 10000;

/** The single logical game "table" clients join by default. */
export const DEFAULT_GAME_ID = "main";

export const DEFAULT_CONFIG: GameConfig = {
  minBet: 100,
  maxBet: 5000,
  payoutMultiplier: 2.0,
  roundDurationMs: 15000,
  revealIntervalMs: 700,
  maxDailyBetPerUser: 100000,
  dailyBonusLadder: [100, 150, 250, 350, 500, 750, 1000],
  enabled: true,
};

function mergeConfig(partial: Partial<GameConfig> | undefined): GameConfig {
  return { ...DEFAULT_CONFIG, ...(partial ?? {}) };
}

/** Reads the current config, falling back to defaults if none is stored. */
export async function getGameConfig(): Promise<GameConfig> {
  const snap = await db.doc("config/game").get();
  return mergeConfig(snap.exists ? (snap.data() as Partial<GameConfig>) : undefined);
}

/** Reads the config, seeding the stored document with defaults if absent. */
export async function ensureGameConfig(): Promise<GameConfig> {
  const ref = db.doc("config/game");
  const snap = await ref.get();
  if (!snap.exists) {
    await ref.set(DEFAULT_CONFIG, { merge: true });
    return { ...DEFAULT_CONFIG };
  }
  return mergeConfig(snap.data() as Partial<GameConfig>);
}

/** Validates and normalizes an admin-supplied partial config patch. */
export function sanitizeConfigPatch(input: unknown): Partial<GameConfig> {
  if (typeof input !== "object" || input === null) {
    throw new Error("config patch must be an object");
  }
  const src = input as Record<string, unknown>;
  const out: Partial<GameConfig> = {};
  const numeric: (keyof GameConfig)[] = [
    "minBet",
    "maxBet",
    "payoutMultiplier",
    "roundDurationMs",
    "revealIntervalMs",
    "maxDailyBetPerUser",
  ];
  for (const key of numeric) {
    if (src[key] !== undefined) {
      const v = Number(src[key]);
      if (!Number.isFinite(v) || v < 0) throw new Error(`invalid ${key}`);
      (out[key] as number) = v;
    }
  }
  if (src.enabled !== undefined) out.enabled = Boolean(src.enabled);
  if (src.dailyBonusLadder !== undefined) {
    const ladder = src.dailyBonusLadder;
    if (!Array.isArray(ladder) || ladder.some((n) => !Number.isFinite(Number(n)) || Number(n) < 0)) {
      throw new Error("invalid dailyBonusLadder");
    }
    out.dailyBonusLadder = ladder.map((n) => Math.floor(Number(n)));
  }
  return out;
}
