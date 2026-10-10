// tasteDeals.ts — العروض حسب ذوق العميل (الموجة ٤ من «خطة سد الفجوات»).
//
// الخطة: «العرض يتبعت لو طابق ذوقك بس، مرة في اليوم بالكتير»، و«محلاتك المتكررة من الفواتير — العرض اللي فيها ياخد
// أولوية». الأدوات كانت موجودة متفرقة (`fetch_live_deals` بحث حي، `interests` في الملف، أسامي المحلات في الحركات)
// والناقص الربط. هنا: الأصناف = قايمة الشراء المفتوحة الأول (احتياج حقيقي) وبعدها الاهتمامات؛ البحث مرة في تحية الصبح؛
// والعرض بيتقال لو صنفه من الأصناف دي بس، ومحل حقيقي، وسعر أو خصم. ونفس العرض (صنف + محل) مايتقالش تاني أسبوع.
//
// مش وقت عروض: الميزانية في خطر (threat OVER/DANGER)، أو وضع الطوارئ («أنا مفلس») شغال، أو البيت في ظرف — العرض
// تشجيع على صرف.
// مفيش مصدر للعروض بمفتاح؛ البحث هو اللي في zad-core-intelligence (جوجل عبر جيميناي، وإلا بحث ويب عادي).

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { countryNameAr, itemKey } from "./shared.ts";
import { isBrokeModeActive } from "../_shared/brokeMode.ts";

export const MAX_TASTE_ITEMS = 5;
export const FAVORITE_MIN_VISITS = 3;
export const FAVORITE_WINDOW_DAYS = 60;
export const DEAL_REPEAT_DAYS = 7;

/** البحث (fetch_live_deals). index.ts بيوصّله وقت التشغيل؛ من غيره مفيش عروض — والتستات مابتكلمش النت. */
export const dealSource: { search: (payload: Record<string, unknown>, userId: string) => Promise<unknown> } = {
  search: () => Promise.resolve(null),
};

export interface TasteDeal {
  item: string;
  store: string;
  price: number | null;
  discount_percent: number | null;
  note: string | null;
  /** في محل من محلاته المتكررة. */
  favorite: boolean;
  /** صنف + محل — عليه بيتعمل منع التكرار. */
  key: string;
}

/** الأصناف اللي بندوّر لها: قايمة الشراء المفتوحة الأول، وبعدها الاهتمامات. مفيش تكرار، ٥ بالكتير. */
export function tasteItems(shopping: readonly string[], interests: readonly string[], max = MAX_TASTE_ITEMS): string[] {
  const out: string[] = [];
  const seen = new Set<string>();
  for (const raw of [...shopping, ...interests]) {
    const name = String(raw ?? "").replace(/\s+/g, " ").trim().slice(0, 40);
    const key = itemKey(name);
    if (name.length < 2 || seen.has(key)) continue;
    seen.add(key);
    out.push(name);
    if (out.length >= max) break;
  }
  return out;
}

/** محلاته المتكررة: اسم تاجر اتكرر ٣ مرات أو أكتر آخر ٦٠ يوم (اسم باكدج تطبيق مش محل). */
export function favoriteStores(rows: ReadonlyArray<{ merchant_name: string | null }>): string[] {
  const counts = new Map<string, { name: string; n: number }>();
  for (const r of rows) {
    const name = String(r.merchant_name ?? "").trim();
    if (name.length < 2 || /^[a-z0-9_]+(\.[a-z0-9_]+)+$/i.test(name)) continue;
    const key = itemKey(name);
    const c = counts.get(key) ?? { name, n: 0 };
    c.n++;
    counts.set(key, c);
  }
  return [...counts.values()].filter((c) => c.n >= FAVORITE_MIN_VISITS).sort((a, b) => b.n - a.n).map((c) => c.name);
}

const sameName = (a: string, b: string) => {
  const ka = itemKey(a);
  const kb = itemKey(b);
  return ka.length >= 2 && kb.length >= 2 && (ka.includes(kb) || kb.includes(ka));
};

/**
 * العرض اللي يتقال، أو null. لازم: صنفه من أصناف الذوق، محل باسم، وسعر أو خصم موجب. الأولوية: محل من محلاته،
 * بعدها أكبر خصم. [skip] = مفاتيح اتقالت آخر أسبوع.
 */
export function pickDeal(raw: unknown, items: readonly string[], favorites: readonly string[], skip: ReadonlySet<string>): TasteDeal | null {
  if (!Array.isArray(raw)) return null;
  const found: TasteDeal[] = [];
  for (const d of raw as Array<Record<string, unknown>>) {
    const item = String(d?.item ?? "").trim().slice(0, 60);
    const store = String(d?.store ?? "").trim().slice(0, 60);
    const price = Number(d?.price);
    const discount = Number(d?.discount_percent);
    const hasPrice = Number.isFinite(price) && price > 0;
    const hasDiscount = Number.isFinite(discount) && discount > 0 && discount < 100;
    if (!item || store.length < 2 || (!hasPrice && !hasDiscount)) continue;
    const wanted = items.find((w) => sameName(w, item));
    if (!wanted) continue;
    const key = `deal:${itemKey(wanted)}:${itemKey(store)}`;
    if (skip.has(key)) continue;
    found.push({
      item, store, key,
      price: hasPrice ? Math.round(price * 100) / 100 : null,
      discount_percent: hasDiscount ? Math.round(discount) : null,
      note: typeof d?.note === "string" && d.note.trim() ? d.note.trim().slice(0, 120) : null,
      favorite: favorites.some((f) => sameName(f, store)),
    });
  }
  found.sort((a, b) => Number(b.favorite) - Number(a.favorite) || (b.discount_percent ?? 0) - (a.discount_percent ?? 0));
  return found[0] ?? null;
}

/** مفاتيح العروض اللي اتقالت (facts.taste_deal.key في تحيات الصبح). */
export function askedDealKeys(rows: ReadonlyArray<{ facts?: unknown }> | null | undefined): Set<string> {
  const keys = new Set<string>();
  for (const r of rows ?? []) {
    const key = (r?.facts as { taste_deal?: { key?: unknown } } | null)?.taste_deal?.key;
    if (typeof key === "string" && key) keys.add(key);
  }
  return keys;
}

/** عرض الصبح: القرايات، البحث، والاختيار. أي فشل = مفيش عرض. */
export async function loadTasteDeal(sb: SupabaseClient, userId: string, now = Date.now()): Promise<TasteDeal | null> {
  try {
    const [{ data: shop }, { data: profile }, { data: user }, { data: txns }, { data: past }, broke] = await Promise.all([
      sb.from("zad_shopping_list").select("item_name").eq("user_id", userId).eq("is_purchased", false).limit(20),
      sb.from("zad_customer_profile").select("interests").eq("user_id", userId).maybeSingle(),
      sb.from("zad_users").select("country").eq("id", userId).maybeSingle(),
      sb.from("zad_transactions").select("merchant_name").eq("user_id", userId).eq("txn_kind", "expense")
        .gte("created_at", new Date(now - FAVORITE_WINDOW_DAYS * 86_400_000).toISOString()).limit(500),
      sb.from("zad_voice_moments").select("facts").eq("user_id", userId).eq("moment", "morning_greeting").eq("status", "sent")
        .gte("created_at", new Date(now - DEAL_REPEAT_DAYS * 86_400_000).toISOString()).limit(20),
      // فشل القراية = اعتبره شغال: عرض في يوم «أنا مفلس» أوحش من يوم من غير عرض.
      sb.from("zad_broke_mode").select("ends_at,ended_at").eq("user_id", userId).maybeSingle()
        .then((r) => r.error ? true : isBrokeModeActive(r.data as { ends_at?: string | null; ended_at?: string | null } | null, now), () => true),
    ]);
    if (broke) return null;
    const interests = (profile as { interests?: unknown } | null)?.interests;
    const items = tasteItems(
      ((shop ?? []) as Array<{ item_name: string }>).map((r) => r.item_name),
      Array.isArray(interests) ? interests.map(String) : [],
    );
    const country = String((user as { country?: string | null } | null)?.country ?? "").toUpperCase();
    if (items.length === 0 || !/^[A-Z]{2}$/.test(country)) return null;
    const res = await dealSource.search({ items, location: countryNameAr(country), country }, userId);
    return pickDeal(
      (res as { deals?: unknown } | null)?.deals,
      items,
      favoriteStores((txns ?? []) as Array<{ merchant_name: string | null }>),
      askedDealKeys(past as Array<{ facts?: unknown }>),
    );
  } catch (e) {
    console.warn("[taste_deal] failed:", (e as Error)?.message);
    return null;
  }
}
