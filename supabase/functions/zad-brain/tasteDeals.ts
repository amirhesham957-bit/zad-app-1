// tasteDeals.ts — العروض حسب ذوق العميل (الموجة ٤ من «خطة سد الفجوات»).
//
// الخطة: «العرض يتبعت لو طابق ذوقك بس، مرة في اليوم بالكتير»، و«محلاتك المتكررة من الفواتير — العرض اللي فيها ياخد
// أولوية». الأدوات كانت موجودة متفرقة (`fetch_live_deals` بحث حي، `interests` في الملف، أسامي المحلات في الحركات)
// والناقص الربط. هنا: الأصناف = قايمة الشراء المفتوحة الأول (احتياج حقيقي) وبعدها الاهتمامات؛ البحث مرة في تحية الصبح؛
// والعرض بيتقال لو صنفه من الأصناف دي بس، ومحل حقيقي، وسعر أو خصم. ونفس العرض (صنف + محل) مايتقالش تاني أسبوع.
//
// مش وقت عروض: الميزانية في خطر (threat OVER/DANGER)، أو وضع الطوارئ («أنا مفلس») شغال، أو البيت في ظرف — العرض
// تشجيع على صرف.
// المصدر الأول من ٢٦/١٠ (ZAD_PLAN ٤.٨/٤.٩): zad_deals — عروض متخزّنة بمحلها ومصدرها وتاريخها، من غير بحث جديد.
// البحث الحي (zad-core-intelligence) بقى احتياطي لما مفيش عرض متخزّن يطابق. والاحتياج: قايمة الشراء، وبعدها اللي
// هيخلص خلال أسبوع (zad_home_state)، وبعدها الاهتمامات.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { countryNameAr, itemKey, travelContext } from "./shared.ts";
import { isBrokeModeActive } from "../_shared/brokeMode.ts";
import { householdFamilyId, householdFilter } from "../_shared/household.ts";
import { offerMatchesNeed } from "./productIdentity.ts";

export const MAX_TASTE_ITEMS = 5;
export const FAVORITE_MIN_VISITS = 3;
export const FAVORITE_WINDOW_DAYS = 60;
export const DEAL_REPEAT_DAYS = 7;
/** آخر نقطة للعميل أقدم من كده = مش بيته ولا مكانه دلوقتي (ZAD_PLAN ٤.٧). */
export const NEARBY_POINT_MAX_AGE_DAYS = 7;
export const NEARBY_RADIUS_METERS = 3000;

/** البحث (fetch_live_deals). index.ts بيوصّله وقت التشغيل؛ من غيره مفيش عروض — والتستات مابتكلمش النت. */
export const dealSource: { search: (payload: Record<string, unknown>, userId: string) => Promise<unknown> } = {
  search: () => Promise.resolve(null),
};

/** المحلات حوالين نقطة (nearby_pois — جوجل ثم LocationIQ، متخزّن لكل خلية). index.ts بيوصّله. */
export const nearbySource: { search: (payload: Record<string, unknown>, userId: string) => Promise<unknown> } = {
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
  /** في محل حوالين آخر نقطة ليه (٣ كم). */
  nearby?: boolean;
  /** الفلوس ضيقة (الميزانية في خطر أو «أنا مفلس»): أرخص سعر لحاجة ناقصة، مش عرض. */
  tight?: boolean;
  /** صنف + محل — عليه بيتعمل منع التكرار. */
  key: string;
  /** من zad_deals بس: نوع المصدر ورابطه ولحد إمتى. البحث الحي مالوش مصدر متخزّن. */
  source?: { kind: string; url: string | null; until: string | null } | null;
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
 * بعدها محل قريب منه ([nearby] = أسامي محلات حوالين آخر نقطة)، بعدها أكبر خصم. [skip] = مفاتيح اتقالت آخر أسبوع.
 *
 * [tight] (ZAD_PLAN ٤.٨، الفلوس ضيقة): [items] هي النواقص بس بترتيب الأهمية، والسعر شرط. أول ناقص ليه عرض
 * بياخد الخانة، وجواه الأرخص — محله المعتاد مش ميزة لو أغلى — والقريب لو السعر واحد.
 */
export function pickDeal(
  raw: unknown,
  items: readonly string[],
  favorites: readonly string[],
  skip: ReadonlySet<string>,
  nearby: readonly string[] = [],
  tight = false,
): TasteDeal | null {
  if (!Array.isArray(raw)) return null;
  const found: TasteDeal[] = [];
  for (const d of raw as Array<Record<string, unknown>>) {
    const item = String(d?.item ?? "").trim().slice(0, 60);
    const store = String(d?.store ?? "").trim().slice(0, 60);
    const price = Number(d?.price);
    const discount = Number(d?.discount_percent);
    const hasPrice = Number.isFinite(price) && price > 0;
    const hasDiscount = Number.isFinite(discount) && discount > 0 && discount < 100;
    if (!item || store.length < 2 || (!hasPrice && !hasDiscount) || (tight && !hasPrice)) continue;
    const wanted = items.find((w) => offerMatchesNeed(w, item));
    if (!wanted) continue;
    const key = `deal:${itemKey(wanted)}:${itemKey(store)}`;
    if (skip.has(key)) continue;
    const src = d?.source as { kind?: unknown; url?: unknown; until?: unknown } | undefined;
    found.push({
      item, store, key,
      ...(src && typeof src.kind === "string"
        ? { source: { kind: src.kind, url: typeof src.url === "string" ? src.url : null, until: typeof src.until === "string" ? src.until.slice(0, 10) : null } }
        : {}),
      price: hasPrice ? Math.round(price * 100) / 100 : null,
      discount_percent: hasDiscount ? Math.round(discount) : null,
      note: typeof d?.note === "string" && d.note.trim() ? d.note.trim().slice(0, 120) : null,
      favorite: favorites.some((f) => sameName(f, store)),
      nearby: nearby.some((n) => sameName(n, store)),
      ...(tight ? { tight: true } : {}),
    });
  }
  if (tight) {
    const need = (d: TasteDeal) => items.findIndex((w) => offerMatchesNeed(w, d.item));
    found.sort((a, b) => need(a) - need(b) || (a.price ?? 0) - (b.price ?? 0) || Number(b.nearby) - Number(a.nearby));
    return found[0] ?? null;
  }
  found.sort((a, b) =>
    Number(b.favorite) - Number(a.favorite) || Number(b.nearby) - Number(a.nearby) ||
    (b.discount_percent ?? 0) - (a.discount_percent ?? 0)
  );
  return found[0] ?? null;
}

export interface StoredDealRow {
  store: string;
  item_name: string;
  price: number | string;
  price_before: number | string | null;
  source_kind: string;
  source_url: string | null;
  valid_until: string | null;
}

/** صفوف zad_deals بشكل نتيجة البحث اللي [pickDeal] بيقراه: الخصم من السعر قبل العرض، والمصدر معاه. */
export function storedDeals(rows: readonly StoredDealRow[] | null | undefined): Array<Record<string, unknown>> {
  return (rows ?? []).map((r) => {
    const price = Number(r.price);
    const before = Number(r.price_before);
    const discount = Number.isFinite(before) && before > price && price > 0 ? ((before - price) / before) * 100 : null;
    return {
      item: r.item_name, store: r.store, price, discount_percent: discount, note: null,
      source: { kind: r.source_kind, url: r.source_url, until: r.valid_until },
    };
  });
}

/**
 * النقطة اللي نسأل حواليها: آخر موقع للعميل لو عمره أقل من أسبوع، مقرّبة لخانتين (~١ كم) — نقطة البيت
 * التقريبية مش مكانه بالظبط، والجيران بيشاركوا نفس الكاش. null = مفيش نقطة أو قديمة.
 */
export function nearbyPoint(
  row: { last_lat?: number | null; last_lon?: number | null; last_location_at?: string | null } | null | undefined,
  nowMs: number,
): { lat: number; lon: number } | null {
  const lat = Number(row?.last_lat);
  const lon = Number(row?.last_lon);
  const at = Date.parse(String(row?.last_location_at ?? ""));
  if (!row?.last_lat || !row?.last_lon || !Number.isFinite(lat) || !Number.isFinite(lon) || !Number.isFinite(at)) return null;
  if (nowMs - at > NEARBY_POINT_MAX_AGE_DAYS * 86_400_000) return null;
  return { lat: Math.round(lat * 100) / 100, lon: Math.round(lon * 100) / 100 };
}

/** أسامي المحلات من رد nearby_pois ({stores: [{name}]}). */
export function nearbyStoreNames(raw: unknown): string[] {
  const stores = (raw as { stores?: unknown } | null)?.stores;
  if (!Array.isArray(stores)) return [];
  return stores.map((s) => String((s as { name?: unknown })?.name ?? "").trim()).filter((n) => n.length >= 2).slice(0, 20);
}

/** اللي هيخلص خلال أسبوع من حالة البيت (pantry.running_out)، الأقرب الأول. */
export function runningOutNames(state: unknown): string[] {
  const list = (state as { pantry?: { running_out?: unknown } } | null)?.pantry?.running_out;
  return Array.isArray(list) ? list.map((r) => String((r as { name?: unknown })?.name ?? "")).filter(Boolean) : [];
}

/** بلد العرض: البلد اللي العميل فيه دلوقتي (travelContext)، وإلا بلد الحساب. «» لو مش معروف. */
export function dealCountry(
  row: { country?: string | null; travel_country?: string | null; travel_since?: string | null } | null | undefined,
  nowMs: number,
): string {
  return travelContext(row, nowMs)?.in ?? String(row?.country ?? "").trim().toUpperCase();
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
/**
 * [tight] = الميزانية في خطر (OVER/DANGER). هو و«أنا مفلس» مابيقفلوش العرض زي الأول (ZAD_PLAN ٤.٨): بيقصروه على
 * النواقص — اللي هيخلص الأول، وبعده قايمة الشرا — وبأرخص سعر، من غير اهتمامات.
 */
export async function loadTasteDeal(sb: SupabaseClient, userId: string, now = Date.now(), opts: { tight?: boolean } = {}): Promise<TasteDeal | null> {
  try {
    const family = await householdFamilyId(sb, userId);
    const [{ data: shop }, { data: profile }, { data: user }, { data: txns }, { data: past }, broke, { data: home }] = await Promise.all([
      sb.from("zad_shopping_list").select("item_name").or(householdFilter(userId, family)).eq("is_purchased", false).limit(20),
      sb.from("zad_customer_profile").select("interests").eq("user_id", userId).maybeSingle(),
      sb.from("zad_users").select("country,travel_country,travel_since,last_lat,last_lon,last_location_at").eq("id", userId).maybeSingle(),
      sb.from("zad_transactions").select("merchant_name").eq("user_id", userId).eq("txn_kind", "expense")
        .gte("created_at", new Date(now - FAVORITE_WINDOW_DAYS * 86_400_000).toISOString()).limit(500),
      sb.from("zad_voice_moments").select("facts").eq("user_id", userId).eq("moment", "morning_greeting").eq("status", "sent")
        .gte("created_at", new Date(now - DEAL_REPEAT_DAYS * 86_400_000).toISOString()).limit(20),
      // فشل القراية = اعتبره شغال: النواقص بس بأرخص سعر، مش عرض تخزين.
      sb.from("zad_broke_mode").select("ends_at,ended_at").eq("user_id", userId).maybeSingle()
        .then((r) => r.error ? true : isBrokeModeActive(r.data as { ends_at?: string | null; ended_at?: string | null } | null, now), () => true),
      sb.from("zad_home_state").select("state").eq("user_id", userId).maybeSingle(),
    ]);
    const tight = broke || opts.tight === true;
    const interests = (profile as { interests?: unknown } | null)?.interests;
    const shopping = ((shop ?? []) as Array<{ item_name: string }>).map((r) => r.item_name);
    const runningOut = runningOutNames((home as { state?: unknown } | null)?.state);
    const items = tight
      ? tasteItems([...runningOut, ...shopping], [])
      : tasteItems([...shopping, ...runningOut], Array.isArray(interests) ? interests.map(String) : []);
    // ٣.١٤: وهو مسافر، العرض من البلد اللي هو فيه — عرض في محل في بلده مالوش لازمة وهو برّه.
    const country = dealCountry(user as { country?: string | null; travel_country?: string | null; travel_since?: string | null } | null, now);
    if (items.length === 0 || !/^[A-Z]{2}$/.test(country)) return null;
    const favorites = favoriteStores((txns ?? []) as Array<{ merchant_name: string | null }>);
    const skip = askedDealKeys(past as Array<{ facts?: unknown }>);
    // ٤.٧: المحلات حوالين نقطته. فشل أو مفيش نقطة = من غير ترتيب بالقرب، مش من غير عرض.
    const point = nearbyPoint(user as { last_lat?: number | null; last_lon?: number | null; last_location_at?: string | null } | null, now);
    const nearby = point
      ? nearbyStoreNames(
        await nearbySource.search({ ...point, tag: "supermarket", radius_meters: NEARBY_RADIUS_METERS }, userId).catch(() => null),
      )
      : [];
    const { data: stored, error: storedErr } = await sb.from("zad_deals")
      .select("store,item_name,price,price_before,source_kind,source_url,valid_until")
      .eq("country", country).gt("expires_at", new Date(now).toISOString()).limit(300);
    if (storedErr) console.warn("[taste_deal] zad_deals read failed:", storedErr.message);
    const fromStore = pickDeal(storedDeals(stored as StoredDealRow[] | null), items, favorites, skip, nearby, tight);
    if (fromStore) return fromStore;
    const res = await dealSource.search({ items, location: countryNameAr(country), country }, userId);
    return pickDeal((res as { deals?: unknown } | null)?.deals, items, favorites, skip, nearby, tight);
  } catch (e) {
    console.warn("[taste_deal] failed:", (e as Error)?.message);
    return null;
  }
}
