// م٣.٣ (ZAD_OR_PLAN): سؤال المخزن بقيمة المعلومة — سؤال واحد متجمع في الأسبوع بالكتير (لحد ٣ أصناف)، بدل سؤال كل ليلة.
// الأصناف اللي «تستاهل سؤال» (findCheckInCandidates) بتترتب بـinfoValue (checkInQuestion.ts): عدم اليقين في
// تنبؤ TSB (pantryForecast.ts) × قرب الخلاص × من امتى ماحدش قال فاضل قد إيه × ضروري ولا لأ.
// صنف من غير تنبؤ (لا قراية ولا معدل مبدئي) قيمته صفر فمابيتسألش هنا.

import { type CheckInCandidate, MIN_DAYS_BETWEEN_QUESTIONS, pickWeeklyQuestion } from "../_shared/or/checkInQuestion.ts";
import { type LevelReading, pantryForecast } from "../_shared/or/pantryForecast.ts";

const DAY_MS = 86_400_000;

/** أيام من آخر سؤال مخزن (أي حالة)، أو null لو عمره ما اتسأل. */
export function lastAskedDaysAgo(lastSentIso: string | null | undefined, nowMs: number): number | null {
  const t = lastSentIso ? Date.parse(lastSentIso) : NaN;
  return Number.isFinite(t) ? Math.max(0, (nowMs - t) / DAY_MS) : null;
}

/** الأسبوع لسه ماخلصش من آخر سؤال ⇒ مفيش سؤال. */
export function weeklyGateClosed(lastAsked: number | null): boolean {
  return lastAsked !== null && lastAsked < MIN_DAYS_BETWEEN_QUESTIONS;
}

export interface ForecastInput {
  item_name: string;
  quantity: number | string;
  prior_daily: number | string | null;
  readings: LevelReading[] | null;
}

/**
 * الأصناف اللي هتتسأل الأسبوع ده، بالترتيب، من [cands] (اللي تستاهل سؤال). [inputs] = zad_pantry_forecast_inputs.
 * من غير قراية للصنف ⇒ «ماحدش أكد من أسبوعين» (أقصى قدم).
 */
export function weeklyPick<T extends { item_name: string; quantity: number; essential: boolean }>(
  cands: readonly T[],
  inputs: readonly ForecastInput[],
  lastAsked: number | null,
  nowMs: number,
  maxItems = 3,
): T[] {
  if (weeklyGateClosed(lastAsked)) return [];
  const byName = new Map(inputs.map((r) => [r.item_name, r]));
  const scored: CheckInCandidate[] = [];
  for (const c of cands) {
    const inp = byName.get(c.item_name);
    if (!inp) continue;
    const readings = inp.readings ?? [];
    const f = pantryForecast(c.quantity, readings, Number(inp.prior_daily ?? 0), nowMs);
    const last = readings.reduce((m, r) => Math.max(m, Date.parse(r.at) || 0), 0);
    scored.push({
      itemId: c.item_name,
      rate: f.rate,
      low: f.low,
      high: f.high,
      onHand: Math.max(0, Number(c.quantity) || 0),
      essential: c.essential,
      lastConfirmedDaysAgo: last > 0 ? Math.max(0, (nowMs - last) / DAY_MS) : 14,
    });
  }
  const q = pickWeeklyQuestion(scored, lastAsked, maxItems);
  if (!q) return [];
  const byItem = new Map(cands.map((c) => [c.item_name, c]));
  return q.itemIds.map((id) => byItem.get(id)!).filter(Boolean);
}
