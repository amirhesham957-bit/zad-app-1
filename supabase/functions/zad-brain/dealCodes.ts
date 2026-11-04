/**
 * أكواد الخصم من السوشيال (ZAD_PLAN ٤.٢٢، طلب المالك ٤/١١).
 *
 * بوستات وفيديوهات المحلات وتطبيقات التوصيل (إنستجرام ٤.١٢، يوتيوب ٤.١١) فيها «خصم ٣٠٪ بالكود X» من غير صنف ولا سعر.
 * core-intelligence بيطلّع الكود حرف بحرف، والجري الأسبوعي بيخزّنه في zad_deal_codes. هنا: الكود اللي يتقال في رسالة
 * الصبح — بس لتطبيق أو محل العميل بيشتري منه فعلاً، ومرة كل [CODE_REPEAT_DAYS] بالكتير لنفس الكود.
 */

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { deliveryApp } from "../_shared/deliveryApps.ts";
import { productNameKey } from "./productIdentity.ts";
import { dealCountry, FAVORITE_WINDOW_DAYS, favoriteStores } from "./tasteDeals.ts";

/** نفس الكود مايتقالش تاني قبل كده. */
export const CODE_REPEAT_DAYS = 7;
/** الكود اللي مالوش آخر يوم مكتوب بيعيش أسبوع من ما اتلاقى. */
export const CODE_DEFAULT_DAYS = 7;

/** مفتاح المحل: تطبيق التوصيل بمفتاحه (كيتا = Keeta)، وأي محل تاني باسمه. */
export function codeStoreKey(store: string): string {
  return deliveryApp(store)?.key ?? productNameKey(store);
}

export interface FoundCode {
  code?: unknown;
  discount_percent?: unknown;
  discount_amount?: unknown;
  min_order?: unknown;
  valid_until?: unknown;
  source_url?: unknown;
}

/** صفوف zad_deal_codes من رد core-intelligence لمحل واحد. اللي شكله غلط بيتساب (القيد في الجدول بيتأكد تاني). */
export function dealCodeRows(
  target: { country: string; store: string; currency?: string | null },
  codes: unknown,
  source: "instagram" | "youtube",
  now = Date.now(),
): Array<Record<string, unknown>> {
  if (!Array.isArray(codes)) return [];
  const rows: Array<Record<string, unknown>> = [];
  for (const c of codes as FoundCode[]) {
    const code = typeof c?.code === "string" ? c.code : "";
    const url = typeof c?.source_url === "string" ? c.source_url : "";
    if (!/^[A-Z0-9][A-Z0-9_-]{2,23}$/.test(code) || !/^https:\/\//.test(url)) continue;
    const percent = Number(c.discount_percent) || null;
    const amount = Number(c.discount_amount) || null;
    if (!percent && !amount) continue;
    const until = typeof c.valid_until === "string" && Number.isFinite(Date.parse(c.valid_until)) ? c.valid_until : null;
    rows.push({
      country: target.country,
      store: target.store,
      store_key: codeStoreKey(target.store),
      code,
      discount_percent: percent,
      discount_amount: percent ? null : amount,
      currency: target.currency ?? null,
      min_order: Number(c.min_order) || null,
      valid_until: until,
      source_kind: source,
      source_url: url,
      found_at: new Date(now).toISOString(),
      expires_at: until ?? new Date(now + CODE_DEFAULT_DAYS * 86_400_000).toISOString(),
    });
  }
  return rows;
}

export interface CodeRow {
  store: string;
  store_key: string;
  code: string;
  discount_percent: number | null;
  discount_amount: number | null;
  currency: string | null;
  min_order: number | null;
  valid_until: string | null;
  source_kind: string;
  source_url: string;
  found_at?: string | null;
}

export interface DealCodeFact {
  store: string;
  code: string;
  discount_percent: number | null;
  discount_amount: number | null;
  currency: string | null;
  min_order: number | null;
  until: string | null;
  source: string;
  url: string;
}

/**
 * الكود اللي يتقال: محله من محلات العميل ([favorites]، بنفس المفتاح — «Keeta» في البنك = «كيتا» في القايمة)، ومش
 * متقال آخر [CODE_REPEAT_DAYS] ([said])؛ ترتيب المحلات زي ترتيب [favorites] (الأكتر الأول)، وجوه المحل الأحدث الأول.
 */
export function pickDealCode(rows: readonly CodeRow[] | null | undefined, favorites: readonly string[], said: ReadonlySet<string>): DealCodeFact | null {
  const live = [...(rows ?? [])].sort((a, b) => Date.parse(b.found_at ?? "") - Date.parse(a.found_at ?? ""));
  for (const fav of favorites) {
    const key = codeStoreKey(fav);
    if (!key) continue;
    const row = live.find((r) => r.store_key === key && !said.has(r.code));
    if (!row) continue;
    return {
      store: row.store,
      code: row.code,
      discount_percent: row.discount_percent === null ? null : Number(row.discount_percent),
      discount_amount: row.discount_amount === null ? null : Number(row.discount_amount),
      currency: row.currency,
      min_order: row.min_order === null ? null : Number(row.min_order),
      until: row.valid_until ? row.valid_until.slice(0, 10) : null,
      source: row.source_kind,
      url: row.source_url,
    };
  }
  return null;
}

/** الأكواد اللي اتقالت في رسايل الصبح آخر [CODE_REPEAT_DAYS]. */
export function saidCodes(rows: ReadonlyArray<{ facts?: unknown; created_at?: string | null }> | null | undefined, now = Date.now()): Set<string> {
  const out = new Set<string>();
  for (const r of rows ?? []) {
    if (Date.parse(r.created_at ?? "") < now - CODE_REPEAT_DAYS * 86_400_000) continue;
    const code = (r.facts as { deal_code?: { code?: unknown } } | null)?.deal_code?.code;
    if (typeof code === "string") out.add(code);
  }
  return out;
}

/** سطر الكود لرسالة الصبح، أو null. أي فشل = من غير كود. */
export async function loadDealCode(sb: SupabaseClient, userId: string, now = Date.now()): Promise<DealCodeFact | null> {
  try {
    const [{ data: user }, { data: txns }, { data: past }] = await Promise.all([
      sb.from("zad_users").select("country,travel_country,travel_since").eq("id", userId).maybeSingle(),
      sb.from("zad_transactions").select("merchant_name").eq("user_id", userId).eq("txn_kind", "expense")
        .gte("created_at", new Date(now - FAVORITE_WINDOW_DAYS * 86_400_000).toISOString()).limit(500),
      sb.from("zad_voice_moments").select("facts,created_at").eq("user_id", userId).eq("moment", "morning_greeting")
        .gte("created_at", new Date(now - CODE_REPEAT_DAYS * 86_400_000).toISOString()).limit(20),
    ]);
    const country = dealCountry(user as { country?: string | null; travel_country?: string | null; travel_since?: string | null } | null, now);
    if (!/^[A-Z]{2}$/.test(country)) return null;
    const favorites = favoriteStores((txns ?? []) as Array<{ merchant_name: string | null }>);
    if (!favorites.length) return null;
    const { data: codes, error } = await sb.from("zad_deal_codes")
      .select("store,store_key,code,discount_percent,discount_amount,currency,min_order,valid_until,source_kind,source_url,found_at")
      .eq("country", country).gt("expires_at", new Date(now).toISOString()).limit(200);
    if (error) {
      console.warn("[deal_code] read failed:", error.message);
      return null;
    }
    return pickDealCode(codes as CodeRow[] | null, favorites, saidCodes(past as Array<{ facts?: unknown; created_at?: string | null }>, now));
  } catch (e) {
    console.warn("[deal_code] failed:", (e as Error)?.message);
    return null;
  }
}
