// crowdFloor.ts — أرضية الجمهور (الموجة ٨، ٢٠٢٦-١٠-١١).
//
// قرار المالك: «أرضية الـ٣ بيوت والتأمين الخصوصي للبلاغات». أي رقم من الجمهور (سعر معتاد، اتجاه، أرخص في
// فئة) لازم يكون من بلاغات ٣ بيوت مختلفة على الأقل — أفراد العيلة الواحدة بيت واحد — وإلا مابيتقالش:
//   - خصوصية: مع عملاء قليلين، «متوسط» من بيت واحد هو سعر اللي جارك اشتراه وإمتى.
//   - صحة: «سعر السوق» من بيت واحد مش سعر سوق.
// وقبل الحساب، البلاغات الشاذة بتتشال: أكتر من ٣ أضعاف الوسيط أو أقل من تلته (غلط كتابة، أو سعر كرتونة
// اتكتب كسعر علبة). نفس القاعدة في SQL (20261011250000).

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

export const CROWD_MIN_HOMES = 3;

export function medianOf(values: number[]): number | null {
  const v = values.filter((x) => Number.isFinite(x)).sort((a, b) => a - b);
  if (v.length === 0) return null;
  const mid = Math.floor(v.length / 2);
  return v.length % 2 ? v[mid] : (v[mid - 1] + v[mid]) / 2;
}

/** من غير الشاذ: بين تلت الوسيط و٣ أضعافه. أقل من ٣ بلاغات = زي ما هي (مفيش وسيط يتقاس بيه). */
export function withoutOutliers<T extends { price: number | null }>(rows: T[]): T[] {
  const priced = rows.filter((r) => Number(r.price) > 0);
  if (priced.length < 3) return priced;
  const m = medianOf(priced.map((r) => Number(r.price)))!;
  return priced.filter((r) => Number(r.price) <= m * 3 && Number(r.price) >= m / 3);
}

/** كام بيت مختلف بلّغ — عضو عيلة = عيلته (homeOf)، وإلا نفسه. بلاغ من غير صاحب مابيتعدّش. */
export function homesIn(rows: Array<{ user_id?: string | null }>, homeOf: ReadonlyMap<string, string>): number {
  const homes = new Set<string>();
  for (const r of rows) if (r.user_id) homes.add(homeOf.get(r.user_id) ?? r.user_id);
  return homes.size;
}

/** بيت كل مبلّغ: عيلته لو في عيلة. فشل القراية = كل واحد بيت لوحده (الأرضية بتفضل ٣ ناس على الأقل). */
export async function homeMap(sb: SupabaseClient, userIds: Iterable<string>): Promise<Map<string, string>> {
  const ids = [...new Set([...userIds].filter(Boolean))];
  const map = new Map<string, string>();
  if (ids.length === 0) return map;
  const { data, error } = await sb.from("family_members").select("user_id,family_id").in("user_id", ids);
  if (error) {
    console.error("[crowd] family lookup failed:", error.message);
    return map;
  }
  for (const r of (data ?? []) as Array<{ user_id: string | null; family_id: string | null }>) {
    if (r.user_id && r.family_id) map.set(r.user_id, `f:${r.family_id}`);
  }
  return map;
}
