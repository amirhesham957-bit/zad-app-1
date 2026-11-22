// م٦.٣: يقرا القفزات (readSurges) ويسجّلها مجمّعة بس: صنف + عدد بيوت + عدد إشارات + المعتاد + z.
// مفيش user_id ولا member_id. حد ٥ بيوت متفحوص هنا وفي الكاتب (zad_trend_surge_record) وفي check الجدول.
// الهايب لوحده مش سبب ترشيح: مفيش حقل «اشتري» في اللي بيتسجّل.
import { MIN_HOUSES } from "./trendSurge.ts";
import { readSurges } from "./trendSurgeData.ts";
import type { Rpc } from "./restockAvailabilityData.ts";

/** يسجّل قفزات اليوم ويرجّع عدد الصفوف. فشل القراية أو الكتابة يرمي خطأ. */
export async function recordSurges(sb: Rpc, args: { asOf?: string } = {}): Promise<number> {
  const day = args.asOf ?? new Date().toISOString().slice(0, 10);
  const surges = (await readSurges(sb, { asOf: day })).filter((s) => s.houses >= MIN_HOUSES);
  if (surges.length === 0) return 0;
  const rows = surges.map((s) => ({ item: s.item, houses: s.houses, count: s.count, baseline: s.baseline, z: s.z }));
  const { data, error } = await sb.rpc("zad_trend_surge_record", { p_day: day, p_rows: rows });
  if (error) throw new Error(`zad_trend_surge_record: ${error.message}`);
  return typeof data === "number" ? data : rows.length;
}
