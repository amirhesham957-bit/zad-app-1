/**
 * م٣.١ موصّل: قراءات المخزن (zad_inventory_observations) ← سلسلة طلب يومية ← TSB (tsb.ts) مع المعدل
 * المبدئي للبيت، ونطاق للأيام الباقية. حساب بس: مابيقراش ومابيكتبش.
 *
 * القراية `qty` هي الموجود ساعتها (مش الكمية المشتراة). نزول بين قرايتين بينهم ساعة على الأقل = استهلاك
 * بيتوزع بالتساوي على الأيام اللي بينهم، زي `zad_recompute_consumption`. طلوع = شرا: مافيهوش إشارة.
 */

import { daysUntilEmpty, forecastItem, type ItemForecast } from "./tsb.ts";

/** وزن المعدل المبدئي بالأيام: بعد أسبوعين قراية البيت بتغلب. */
export const PRIOR_WEIGHT_DAYS = 7;
/** أطول تاريخ بيدخل الحساب. */
export const HISTORY_DAYS = 90;
const DAY_MS = 86_400_000;
const MIN_GAP_MS = 3_600_000;

export interface LevelReading {
  qty: number;
  at: string;
}

/**
 * سلسلة الطلب اليومي (الأقدم الأول) من أول قراية لحد النهارده، بأقصى [maxDays] يوم. القرايات الغلط
 * (كمية سالبة أو مش رقم، أو تاريخ مش مفهوم أو في المستقبل) بتتشال.
 */
export function dailyDemandFromLevels(
  readings: readonly LevelReading[],
  nowMs: number,
  maxDays = HISTORY_DAYS,
): number[] {
  const pts = readings
    .map((r) => ({ qty: Number(r.qty), t: Date.parse(r.at) }))
    .filter((r) => Number.isFinite(r.qty) && r.qty >= 0 && Number.isFinite(r.t) && r.t <= nowMs)
    .sort((a, b) => a.t - b.t);
  if (pts.length === 0) return [];
  const today = Math.floor(nowMs / DAY_MS);
  const startDay = Math.max(Math.floor(pts[0].t / DAY_MS), today - maxDays + 1);
  const days = today - startDay + 1;
  const out = new Array<number>(days).fill(0);
  for (let i = 1; i < pts.length; i++) {
    const a = pts[i - 1];
    const b = pts[i];
    if (b.qty >= a.qty || b.t - a.t < MIN_GAP_MS) continue;
    // النزول بيتوزع على الأيام من يوم القراية الأولى لحد يوم التانية، بنسبة الوقت في كل يوم.
    const drop = a.qty - b.qty;
    const span = b.t - a.t;
    for (let d = Math.floor(a.t / DAY_MS); d <= Math.floor(b.t / DAY_MS); d++) {
      const lo = Math.max(a.t, d * DAY_MS);
      const hi = Math.min(b.t, (d + 1) * DAY_MS);
      const idx = d - startDay;
      if (hi > lo && idx >= 0 && idx < days) out[idx] += drop * (hi - lo) / span;
    }
  }
  return out.map((x) => Math.round(x * 1e6) / 1e6);
}

export interface PantryForecast extends ItemForecast {
  /** الأيام الباقية بالمعدل، وبحدود النطاق (null = مفيش استهلاك متوقع). */
  daysLeft: number | null;
  daysLeftLow: number | null;
  daysLeftHigh: number | null;
}

const round1 = (x: number | null) => x === null ? null : Math.round(x * 10) / 10;

/**
 * توقع صنف واحد. [priorDaily] = المعدل المبدئي للبيت (أفراد × استهلاك الفرد ÷ العبوة)، أو 0 لو مش معروف.
 * الأيام الباقية: الأقل بالحد العالي للمعدل، والأكتر بالحد الواطي.
 */
export function pantryForecast(
  onHand: number,
  readings: readonly LevelReading[],
  priorDaily: number,
  nowMs: number,
): PantryForecast {
  const prior = Number.isFinite(priorDaily) && priorDaily > 0 ? priorDaily : 0;
  const series = dailyDemandFromLevels(readings, nowMs);
  const f = forecastItem(series, { dailyRate: prior, weight: prior > 0 ? PRIOR_WEIGHT_DAYS : 0 });
  const qty = Number.isFinite(onHand) && onHand > 0 ? onHand : 0;
  return {
    ...f,
    daysLeft: round1(daysUntilEmpty(qty, f.rate)),
    daysLeftLow: round1(daysUntilEmpty(qty, f.high)),
    daysLeftHigh: round1(daysUntilEmpty(qty, f.low)),
  };
}
