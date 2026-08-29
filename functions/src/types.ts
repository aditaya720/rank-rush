/**
 * Shared, transport-agnostic types for the Rank Rush game engine.
 *
 * This module contains ONLY types/interfaces (no runtime code and no Firebase
 * imports) so the pure engine can be unit-tested and mirrored on the client.
 *
 * VIRTUAL COINS ONLY: every "coin"/"amount" in this project is a virtual,
 * non-cashable in-game currency. There is no real-money concept anywhere.
 */

export type Suit = "hearts" | "diamonds" | "clubs" | "spades";

export type RankName =
  | "ace"
  | "two"
  | "three"
  | "four"
  | "five"
  | "six"
  | "seven"
  | "eight"
  | "nine"
  | "ten"
  | "jack"
  | "queen"
  | "king";

export type Side = "left" | "right";

/** Authoritative round lifecycle (mirrored by the Flutter `GameStatus` enum). */
export type GameStatus =
  | "waiting"
  | "betting"
  | "locked"
  | "revealing"
  | "finished"
  | "cancelled";

export type TransactionType =
  | "BET"
  | "WIN"
  | "LOSS"
  | "BONUS"
  | "REFUND"
  | "ADMIN_ADJUSTMENT";

export type Role = "USER" | "ADMIN" | "SUPER_ADMIN";

/** A single immutable playing card. */
export interface CardData {
  /** Stable id, e.g. "seven_hearts". */
  id: string;
  suit: Suit;
  rank: RankName;
  /** ace=1, two..ten=face value, jack=11, queen=12, king=13. */
  numericRank: number;
  /** Short display code, e.g. "7H", "10S", "AH". */
  code: string;
}

/** One step of the alternating reveal (LEFT on even index, RIGHT on odd). */
export interface RevealStep {
  /** 0-based position within the post-target remaining deck. */
  index: number;
  side: Side;
  card: CardData;
}

/**
 * Tunable, server-owned game configuration. Never trusted from the client;
 * a snapshot is copied onto each round for auditability.
 */
export interface GameConfig {
  /** Minimum virtual-coin stake. */
  minBet: number;
  /** Maximum virtual-coin stake per bet. */
  maxBet: number;
  /** Winning side returns floor(stake * payoutMultiplier). */
  payoutMultiplier: number;
  /** Length of the betting window in milliseconds. */
  roundDurationMs: number;
  /** Per-card client animation cadence in milliseconds (visual only). */
  revealIntervalMs: number;
  /** Responsible-play: soft cap on total virtual stake per user per UTC day. */
  maxDailyBetPerUser: number;
  /** 7-day daily-bonus ladder in virtual coins (index 0 => day 1). */
  dailyBonusLadder: number[];
  /** Master switch — when false, createRound/placeBet are rejected. */
  enabled: boolean;
}
