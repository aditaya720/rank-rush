/**
 * Firebase Admin initialization and shared Firestore handles.
 * This is the only place the Admin SDK is bootstrapped.
 */

import { getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";

if (getApps().length === 0) {
  initializeApp();
}

export const db = getFirestore();
export { FieldValue, Timestamp };

/** Generates a random, collision-resistant document id (optionally prefixed). */
export function newId(prefix = ""): string {
  return `${prefix}${db.collection("_ids").doc().id}`;
}

/** UTC calendar day key, e.g. "2026-08-29", used for daily caps/bonuses. */
export function utcDayKey(date: Date = new Date()): string {
  return date.toISOString().slice(0, 10);
}
