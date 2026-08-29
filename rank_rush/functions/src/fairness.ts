/**
 * Provably-fair primitives.
 *
 * The commitment scheme:
 *   1. Before a round opens, the server generates a 32-byte `serverSeed` and
 *      publishes `serverSeedHash = SHA256(serverSeed)`.
 *   2. The entire deck order is derived deterministically from
 *      (serverSeed, roundId) using the algorithm below.
 *   3. After the round completes, the server reveals `serverSeed`. Anyone can
 *      recompute the deck and confirm it matches `deckHash`, and that
 *      SHA256(serverSeed) equals the previously published `serverSeedHash`.
 *
 * The exact same algorithm is re-implemented in Dart
 * (lib/core/security/provably_fair.dart) so the client can verify independently.
 * See docs/FAIRNESS.md for the byte-level specification.
 */

import { createHash, randomBytes } from "crypto";

/** Hex-encoded SHA-256 of a UTF-8 string. */
export function sha256Hex(input: string): string {
  return createHash("sha256").update(input, "utf8").digest("hex");
}

/** Cryptographically-secure 32-byte server seed as 64 hex chars. */
export function generateServerSeed(): string {
  return randomBytes(32).toString("hex");
}

/**
 * Deterministic PRNG driven by SHA-256.
 *
 * Byte stream: for k = 0, 1, 2, ...
 *     block(k) = SHA256( UTF8( `${serverSeed}:${roundId}:${k}` ) )   // 32 bytes
 * The blocks are concatenated and consumed 4 bytes at a time as big-endian
 * unsigned 32-bit integers. Uniform integers in [0, n) are produced with
 * rejection sampling to avoid modulo bias.
 */
export class SeededRng {
  private readonly serverSeed: string;
  private readonly roundId: string;
  private blockIndex = 0;
  private buffer: Buffer = Buffer.alloc(0);
  private offset = 0;

  constructor(serverSeed: string, roundId: string) {
    this.serverSeed = serverSeed;
    this.roundId = roundId;
  }

  private refill(): void {
    const block = createHash("sha256")
      .update(`${this.serverSeed}:${this.roundId}:${this.blockIndex}`, "utf8")
      .digest();
    this.blockIndex += 1;
    const remaining = this.buffer.subarray(this.offset);
    this.buffer = Buffer.concat([remaining, block]);
    this.offset = 0;
  }

  private nextUint32(): number {
    if (this.buffer.length - this.offset < 4) {
      this.refill();
    }
    const value = this.buffer.readUInt32BE(this.offset);
    this.offset += 4;
    return value >>> 0;
  }

  /** Uniform integer in [0, n). Requires 1 <= n <= 2^32. */
  nextInt(n: number): number {
    if (n <= 0 || !Number.isInteger(n)) {
      throw new Error(`nextInt requires a positive integer, got ${n}`);
    }
    if (n === 1) {
      return 0;
    }
    const limit = Math.floor(0x100000000 / n) * n; // largest multiple of n < 2^32
    let x = this.nextUint32();
    while (x >= limit) {
      x = this.nextUint32();
    }
    return x % n;
  }
}
