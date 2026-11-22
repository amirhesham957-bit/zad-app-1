// م٦.٣: قراية قفزات اليوم المجمّعة (zad_trend_surges) كنص «البيوت بتشتري أكتر من المعتاد».
// قراية بس. الجدول عالمي (من غير بلد). مفيش user_id ولا member_id، وحد ٥ بيوت متفحوص هنا تاني.
// الهايب لوحده مش سبب ترشيح: النص وصف بس، مفيش «اشتري»، و recommendBuy دايماً false.
import { MIN_HOUSES } from "./trendSurge.ts";
import type { Rpc } from "./restockAvailabilityData.ts";

export interface SurgeRead {
  item: string;
  houses: number;
  count: number;
  baseline: number;
  z: number;
  recommendBuy: false;
}

interface Row {
  item_key: string;
  houses: number | string;
  signal_count: number | string;
  baseline: number | string;
  z: number | string;
}

/** قفزات اليوم، الأعلى z الأول. فشل القراية يرمي خطأ. */
export async function readTodaySurges(sb: Rpc, args: { day?: string; limit?: number } = {}): Promise<SurgeRead[]> {
  const { data, error } = await sb.rpc("zad_trend_surges_read", { p_day: args.day ?? null, p_limit: args.limit ?? 10 });
  if (error) throw new Error(`zad_trend_surges_read: ${error.message}`);
  const out: SurgeRead[] = [];
  for (const r of Array.isArray(data) ? (data as Row[]) : []) {
    const houses = Number(r.houses), count = Number(r.signal_count), baseline = Number(r.baseline), z = Number(r.z);
    if (![houses, count, baseline, z].every(Number.isFinite) || houses < MIN_HOUSES) continue;
    if (typeof r.item_key !== "string" || !r.item_key) continue;
    out.push({ item: r.item_key, houses, count, baseline, z, recommendBuy: false });
  }
  return out;
}

/** سطر لكل صنف: «لبن: ٢٠ مرة النهارده مقابل ~٢ في العادة (٨ بيوت)». فاضي لو مفيش قفزات. */
export function surgeText(surges: readonly SurgeRead[]): string {
  if (surges.length === 0) return "";
  const lines = surges.map((s) =>
    `- ${s.item}: ${s.count} مرة النهارده مقابل ~${Math.round(s.baseline * 10) / 10} في العادة (${s.houses} بيوت)`
  );
  return `اللي البيوت بتشتريه أكتر من المعتاد النهارده (أرقام مجمّعة، وصف بس مش نصيحة شرا):\n${lines.join("\n")}`;
}

/** قراية + نص. */
export async function todaySurgeText(sb: Rpc, args: { day?: string; limit?: number } = {}): Promise<string> {
  return surgeText(await readTodaySurges(sb, args));
}
