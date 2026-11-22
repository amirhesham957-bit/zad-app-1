import { accuracyReport, type AccuracyReport, type ForecastOutcome } from "./forecastAccuracy.ts";

/** One settled prediction of an engine model for a household. */
export interface ModelOutcome extends ForecastOutcome {
  /** Engine model name, e.g. "tsb", "safeSpend". */
  model: string;
  householdId: string;
  /** ISO date (YYYY-MM-DD) of the week start, civil date in the account timezone. */
  weekStart: string;
}

export interface ModelWeekReport extends AccuracyReport {
  model: string;
  weekStart: string;
}

/** Weekly accuracy per model, across all households. Sorted by weekStart then model. */
export function weeklyModelReport(rows: readonly ModelOutcome[]): ModelWeekReport[] {
  const groups = new Map<string, { model: string; weekStart: string; rows: ModelOutcome[] }>();
  for (const r of rows) {
    const key = `${r.weekStart}\u0000${r.model}`;
    const g = groups.get(key) ?? { model: r.model, weekStart: r.weekStart, rows: [] };
    g.rows.push(r);
    groups.set(key, g);
  }
  return [...groups.values()]
    .sort((a, b) => a.weekStart.localeCompare(b.weekStart) || a.model.localeCompare(b.model))
    .map((g) => ({ model: g.model, weekStart: g.weekStart, ...accuracyReport(g.rows) }));
}

/** Minimum settled predictions before a household coefficient moves at all. */
export const TUNE_MIN_N = 8;
/** Number of rows at which the correction reaches full strength. */
export const TUNE_FULL_N = 40;
/** Bounds on the per-household multiplier, so one bad stretch cannot swing it. */
export const TUNE_MIN_SCALE = 0.7;
export const TUNE_MAX_SCALE = 1.4;

export interface HouseholdTuning {
  model: string;
  householdId: string;
  n: number;
  /** Multiplier to apply to this model's predictions for this household. 1 = no change. */
  scale: number;
  /** True when scale differs from 1 (enough evidence and non-zero bias). */
  tuned: boolean;
}

function round4(n: number): number {
  return Math.round(n * 1e4) / 1e4;
}

/**
 * Pure per-household coefficient tuning. bias = (sum predicted - sum actual) / sum actual,
 * so the ideal multiplier is 1 / (1 + bias). It is shrunk toward 1 by sample size and clamped.
 * Fewer than TUNE_MIN_N rows, or zero total actual, leaves scale at 1.
 */
export function tuneHouseholdCoefficients(rows: readonly ModelOutcome[]): HouseholdTuning[] {
  const groups = new Map<string, { model: string; householdId: string; rows: ModelOutcome[] }>();
  for (const r of rows) {
    const key = `${r.model}\u0000${r.householdId}`;
    const g = groups.get(key) ?? { model: r.model, householdId: r.householdId, rows: [] };
    g.rows.push(r);
    groups.set(key, g);
  }
  return [...groups.values()]
    .sort((a, b) => a.model.localeCompare(b.model) || a.householdId.localeCompare(b.householdId))
    .map((g) => {
      const n = g.rows.length;
      const rep = accuracyReport(g.rows);
      let scale = 1;
      if (n >= TUNE_MIN_N && rep.bias !== null && 1 + rep.bias > 0) {
        const ideal = 1 / (1 + rep.bias);
        const w = Math.min(1, n / TUNE_FULL_N);
        scale = 1 + (ideal - 1) * w;
        scale = Math.min(TUNE_MAX_SCALE, Math.max(TUNE_MIN_SCALE, scale));
      }
      scale = round4(scale);
      return { model: g.model, householdId: g.householdId, n, scale, tuned: scale !== 1 };
    });
}
