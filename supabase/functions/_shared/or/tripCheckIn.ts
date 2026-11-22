/**
 * Trip check-in (ZAD_OR_PLAN م٧.٤): which question, if any, to ask the traveler right now.
 * Pure and deterministic. Questions go through the attention budget (attentionBudget.ts), at most
 * MAX_QUESTIONS_PER_DAY a day, and only inside a local-time window (start inclusive, end exclusive).
 */
import { type Candidate, planMessages } from "./attentionBudget.ts";

export type TripWindowId = "lunch" | "evening";

export const TRIP_WINDOWS: Readonly<Record<TripWindowId, { start: number; end: number }>> = {
  lunch: { start: 13, end: 15 },
  evening: { start: 20, end: 22 },
};

export const MAX_QUESTIONS_PER_DAY = 2;

/** A question that could be asked. Budget fields mirror attentionBudget's Candidate (never critical). */
export interface TripQuestion extends Pick<Candidate, "id" | "value" | "cost"> {
  window: TripWindowId;
}

/** A question already asked today (local day), with the window it was asked in. */
export interface AskedToday {
  id: string;
  window: TripWindowId;
}

/** The window containing the local hour (fractional hours allowed, e.g. 14.5), or null. */
export function windowAt(localHour: number): TripWindowId | null {
  if (!Number.isFinite(localHour) || localHour < 0 || localHour >= 24) {
    throw new RangeError(`localHour must be in [0, 24): ${localHour}`);
  }
  for (const w of Object.keys(TRIP_WINDOWS) as TripWindowId[]) {
    if (localHour >= TRIP_WINDOWS[w].start && localHour < TRIP_WINDOWS[w].end) return w;
  }
  return null;
}

/**
 * Returns the one question to ask now, or null. Null when outside every window, the daily cap is hit,
 * this window was already asked, or the budget cannot afford any candidate. Among affordable candidates
 * the budget plan decides, then highest value wins; ties go to the smaller id.
 */
export function pickTripQuestion(
  localHour: number,
  askedToday: readonly AskedToday[],
  candidates: readonly TripQuestion[],
  budgetRemaining: number,
): TripQuestion | null {
  const win = windowAt(localHour);
  if (win === null) return null;
  if (askedToday.length >= MAX_QUESTIONS_PER_DAY) return null;
  if (askedToday.some((a) => a.window === win)) return null;

  const askedIds = new Set(askedToday.map((a) => a.id));
  const eligible = candidates.filter((c) => c.window === win && !askedIds.has(c.id));
  const plan = planMessages(
    eligible.map((c) => ({ id: c.id, value: c.value, cost: c.cost, critical: false })),
    budgetRemaining,
  );
  const sent = new Set(plan.send);
  const winners = eligible
    .filter((c) => sent.has(c.id))
    .sort((a, b) => b.value - a.value || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  return winners[0] ?? null;
}
