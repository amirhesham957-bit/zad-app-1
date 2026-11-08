// fuelForecast.ts — إمتى العربية هتحتاج بنزين (طلب المالك ٨/١١).
//
// المصدر الوحيد عندنا فلوس التفويلات ومواعيدها، من البنك أو الشات. مفيش عداد ولا مستوى خزان، فده تقدير مش قياس، والجملة بتقول كده،
// و«لسه معايا» من العميل هي اللي بتصلّحه. قواعد ثابتة، صفر توكنز.

import { itemKey } from "./shared.ts";

const DAY_MS = 86_400_000;
export const FUEL_MIN_FILLS = 3;
/** بيتسأل من قبل الميعاد بيومين لحد بعده بيومين. */
export const FUEL_ASK_BEFORE_DAYS = 2;
export const FUEL_ASK_AFTER_DAYS = 2;

// «غاز» مش هنا عن قصد: فاتورة البيت. و«موبيل» بتمسك موبايل وموبيليا.
const FUEL = /(بنزين|وقود|fuel|petrol|الدريس|aldrees|ساسكو|sasco|توتال|total ?energies|شيل اوت|chillout|مصر للبترول|تعاون للبترول|وطنيه للبترول)/;

export interface FuelTxn {
  amount: number | string | null;
  title?: string | null;
  merchant_name?: string | null;
  category?: string | null;
  created_at: string;
}

export interface FuelForecast {
  next_on: string;
  in_days: number;
  every_days: number;
  avg_amount: number;
  last_days_ago: number;
  last_fill: string;
  confidence: "good" | "rough";
}

export const isFuelSpend = (t: FuelTxn): boolean => FUEL.test(itemKey(`${t.title ?? ""} ${t.merchant_name ?? ""} ${t.category ?? ""}`));

const median = (xs: number[]) => {
  const s = [...xs].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
};

/** التفويلات بالأيام. تفويلتين في يوم واحد = واحدة. أقل من ٣ أو وقف من بدري (عربية اتباعت، سفر) = null. */
export function fuelForecast(txns: readonly FuelTxn[], todayStart: number): FuelForecast | null {
  const byDay = new Map<number, number>();
  for (const t of txns) {
    const at = Date.parse(t.created_at), amount = Number(t.amount);
    if (!isFuelSpend(t) || !Number.isFinite(at) || !(amount > 0)) continue;
    const day = Math.floor(at / DAY_MS);
    byDay.set(day, (byDay.get(day) ?? 0) + amount);
  }
  const days = [...byDay.keys()].sort((a, b) => a - b);
  if (days.length < FUEL_MIN_FILLS) return null;
  const gaps = days.slice(1).map((d, i) => d - days[i]);
  const every = median(gaps);
  const today = Math.floor(todayStart / DAY_MS);
  const last = days[days.length - 1];
  if (every < 1 || today - last > every * 2.5) return null;
  // الفلوس بتتحرق بمعدل: تفويلة أكبر من العادي تعيش أطول. كل التفويلات قبل الأخيرة هي اللي اتحرقت في المدة دي.
  const amounts = days.map((d) => byDay.get(d) as number);
  const burn = amounts.slice(0, -1).reduce((a, b) => a + b, 0) / (last - days[0]);
  const lasts = amounts[amounts.length - 1] / burn;
  const est = Number.isFinite(lasts) && lasts > 0 ? (every + lasts) / 2 : every;
  const next = Math.round(last + est);
  const spread = Math.max(...gaps.map((g) => Math.abs(g - every))) / every;
  return {
    next_on: new Date(next * DAY_MS).toISOString().slice(0, 10),
    in_days: next - today,
    every_days: Math.round(every),
    avg_amount: Math.round(amounts.reduce((a, b) => a + b, 0) / amounts.length),
    last_days_ago: today - last,
    last_fill: new Date(last * DAY_MS).toISOString().slice(0, 10),
    confidence: spread <= 0.25 ? "good" : "rough",
  };
}

/** سطر للشات. فاضي لو مفيش توقع. */
export function fuelForecastLine(f: FuelForecast | null): string {
  if (!f) return "";
  return `تقدير من فلوس تفويلاته (مش عداد العربية): بيفوّل كل حوالي ${f.every_days} يوم بحوالي ${f.avg_amount}، آخر مرة من ${f.last_days_ago} يوم، ` +
    `فالمتوقع يحتاج بنزين بعد حوالي ${Math.max(0, f.in_days)} يوم. ${f.confidence === "rough" ? "مواعيده بتتغير كتير، فقولها كتخمين." : ""}`.trim();
}
