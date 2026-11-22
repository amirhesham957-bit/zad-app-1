// م٦.٣: محوّل رفيع بين دالة القراية zad_trend_signals و trendSurge.ts (الحساب الصافي).
// قراية بس (service_role). الدالة بترجّع أرقام مجمّعة بس وبتخفي أي صنف أقل من ٥ بيوت؛ والمحوّل بيعيد الفحص.
// الهايب لوحده مش سبب ترشيح: النتيجة recommendBuy = false دايماً.
import { detectSurges, MIN_HOUSES, type Surge, type SurgeInput } from "./trendSurge.ts";
import type { Rpc } from "./restockAvailabilityData.ts";

export interface TrendRow {
  item_key: string;
  today_count: number | string;
  houses: number | string;
  baseline: number | string;
}

/** صفوف الدالة -> مدخلات الحساب. صف بأرقام مش سليمة أو أقل من ٥ بيوت بيتشال. */
export function toSurgeInputs(rows: TrendRow[]): SurgeInput[] {
  const out: SurgeInput[] = [];
  for (const r of rows) {
    const count = Number(r.today_count);
    const houses = Number(r.houses);
    const baseline = Number(r.baseline);
    if (![count, houses, baseline].every((n) => Number.isFinite(n) && n >= 0)) continue;
    if (houses < MIN_HOUSES) continue;
    out.push({ item: r.item_key, count, houses, baseline });
  }
  return out;
}

/** يقرا الإشارات المجمّعة ويرجّع القفزات. فشل القراية يرمي خطأ. */
export async function readSurges(
  sb: Rpc,
  args: { asOf?: string; baselineDays?: number } = {},
): Promise<Surge[]> {
  const { data, error } = await sb.rpc("zad_trend_signals", {
    p_as_of: args.asOf ?? null,
    p_baseline_days: args.baselineDays ?? 28,
  });
  if (error) throw new Error(`zad_trend_signals: ${error.message}`);
  const rows = Array.isArray(data) ? (data as TrendRow[]) : [];
  return detectSurges(toSurgeInputs(rows));
}
