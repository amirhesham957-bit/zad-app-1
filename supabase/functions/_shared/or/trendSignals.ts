// م٦.٣: قارئ إشارات الترند. بيقرا zad_trend_signals (مجمّعة: صنف + بلد + يوم، ٥ بيوت على الأقل، من غير أي هوية)
// وبيغذّي detectSurges. الهايب لوحده مش سبب ترشيح: النتيجة recommendBuy دايماً false.
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { detectSurges, type Surge, type SurgeInput } from "./trendSurge.ts";

export const TREND_RPC = "zad_trend_signals";
export const WINDOW_DAYS = 29;

export interface TrendSignalRow {
  country: string;
  item_key: string;
  day: string; // yyyy-mm-dd (UTC)
  signal_count: number;
  houses: number;
}
export interface CountrySurge extends Surge {
  country: string;
}

/** اليوم = النهارده، والمعتاد = متوسط الأيام اللي قبله في النافذة (الأيام اللي مااتجمعتش = صفر). */
export function buildSurgeInputs(
  rows: readonly TrendSignalRow[],
  today: string,
  windowDays = WINDOW_DAYS,
): Array<SurgeInput & { country: string }> {
  const lookback = Math.max(windowDays - 1, 1);
  const byKey = new Map<string, { country: string; item: string; count: number; houses: number; prior: number }>();
  for (const r of rows) {
    const k = `${r.country}|${r.item_key}`;
    const e = byKey.get(k) ?? { country: r.country, item: r.item_key, count: 0, houses: 0, prior: 0 };
    if (r.day === today) {
      e.count = r.signal_count;
      e.houses = r.houses;
    } else if (r.day < today) e.prior += r.signal_count;
    byKey.set(k, e);
  }
  return [...byKey.values()].map((e) => ({ country: e.country, item: e.item, count: e.count, houses: e.houses, baseline: e.prior / lookback }));
}

/** القفزات المعتبرة النهارده لكل بلد. detectSurges بيطبّق حد الـ٥ بيوت تاني (دفاع ثاني فوق حد الـSQL). */
export function surgesFromRows(rows: readonly TrendSignalRow[], today: string): CountrySurge[] {
  const inputs = buildSurgeInputs(rows, today);
  const out: CountrySurge[] = [];
  for (const c of new Set(inputs.map((i) => i.country))) {
    for (const s of detectSurges(inputs.filter((i) => i.country === c))) out.push({ ...s, country: c });
  }
  return out;
}

export async function readTrendSurges(sb: SupabaseClient, now: Date = new Date()): Promise<CountrySurge[]> {
  const { data, error } = await sb.rpc(TREND_RPC, { p_days: WINDOW_DAYS });
  if (error) throw new Error(`${TREND_RPC}: ${error.message}`);
  return surgesFromRows((data ?? []) as TrendSignalRow[], now.toISOString().slice(0, 10));
}
