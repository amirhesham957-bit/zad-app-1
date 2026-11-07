/**
 * موسم العروض (الجمعة البيضاء/البلاك فرايداي — طلب المالك ٤/١١): رسالة يومية على البوت بأحسن العروض اللي البيت محتاجها،
 * كل عرض بصورته ورابطه.
 *
 * مش كل عرض: لازم يبقى على حاجة البيت محتاجها (قايمة الشرا، اللي قرّب يخلص) أو في محل البيت بيشتري منه بخصم ٢٠٪ أو أكتر،
 * أو عرض ناري (٤٠٪ أو أكتر) على حاجة اتشرت قبل كده. نفس العرض مايتبعتش لنفس البيت مرتين في الموسم ([sent]). وأكواد
 * الخصم بس لتطبيقات ومحلات البيت بيطلب منها. الفلوس ضيقة («أنا مفلس») = مفيش رسالة.
 */

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { isBrokeModeActive } from "../_shared/brokeMode.ts";
import { householdFamilyId, householdFilter } from "../_shared/household.ts";
import { offerMatchesNeed } from "./productIdentity.ts";
import { itemKey } from "./shared.ts";
import { codeStoreKey } from "./dealCodes.ts";
import { fetchPreviewImage, previewableUrl } from "../_shared/pagePreview.ts";
import { deliveryApp } from "../_shared/deliveryApps.ts";
import { upcomingSeason } from "../_shared/season.ts";
import { SCHOOL_WINDOW_MARKETS } from "./eventAhead.ts";
import { customerCity, dealCountry, dealsForCity, FAVORITE_WINDOW_DAYS, favoriteStores, runningOutNames } from "./tasteDeals.ts";

/** أقصى عدد كروت في رسالة الموسم. */
export const DIGEST_MAX_DEALS = 4;
export const DIGEST_MAX_CODES = 2;
/** خصم في محل البيت بيشتري منه يستاهل يتقال. */
export const FAVORITE_MIN_SAVING = 20;
/** عرض ناري على حاجة اتشرت قبل كده. */
export const FIRE_MIN_SAVING = 40;

export interface DigestDealRow {
  store: string;
  item_name: string;
  price: number | string;
  price_before?: number | string | null;
  currency?: string | null;
  source_kind: string;
  source_url?: string | null;
  valid_until?: string | null;
  city?: string | null;
}

export interface DigestCard {
  key: string;
  item: string;
  store: string;
  price: number;
  price_before: number | null;
  currency: string;
  saving: number | null;
  why: "need" | "favorite" | "fire" | "top";
  url: string | null;
  source: string;
  photo: string | null;
  until: string | null;
}

export interface DigestCodeRow {
  store: string;
  store_key: string;
  code: string;
  discount_percent: number | string | null;
  discount_amount: number | string | null;
  currency: string | null;
  min_order: number | string | null;
  valid_until: string | null;
  source_kind: string;
  source_url: string;
}

/** صورة العرض: غلاف فيديو يوتيوب بالـid بس (نفس ٤.٢٠). صورة إنستجرام مابتتخزنش — الرابط هو اللي بيوديها. */
export function digestPhoto(kind: string, url: string | null | undefined): string | null {
  if (kind !== "youtube" || typeof url !== "string") return null;
  const id = /^https:\/\/www\.youtube\.com\/watch\?v=([\w-]{6,20})$/.exec(url.trim())?.[1];
  return id ? `https://i.ytimg.com/vi/${id}/hqdefault.jpg` : null;
}

/** مفتاح العرض للسجل: المحل والصنف والسعر — سعر جديد لنفس الصنف عرض جديد. */
export function digestKey(store: string, item: string, price: number): string {
  return `${itemKey(store)}|${itemKey(item)}|${Math.round(price * 100)}`.slice(0, 200);
}

const sameStoreName = (a: string, b: string) => {
  const ka = codeStoreKey(a);
  const kb = codeStoreKey(b);
  return ka.length >= 2 && kb.length >= 2 && (ka === kb || ka.includes(kb) || kb.includes(ka));
};

/**
 * الكروت بالترتيب: الاحتياج الأول (الأكبر توفير)، بعده محلاته، بعده الناري على اللي اتشرى قبل كده. صنف واحد مرة واحدة،
 * ومحل واحد مرتين بالكتير عشان الرسالة ماتبقاش إعلان محل واحد.
 */
export function pickDigest(
  rows: readonly DigestDealRow[] | null | undefined,
  needs: readonly string[],
  favorites: readonly string[],
  bought: readonly string[],
  sent: ReadonlySet<string>,
  max = DIGEST_MAX_DEALS,
): DigestCard[] {
  const scored: Array<DigestCard & { rank: number }> = [];
  for (const r of rows ?? []) {
    const price = Number(r.price);
    const before = Number(r.price_before);
    if (!r.store || !r.item_name || !Number.isFinite(price) || price <= 0) continue;
    const saving = Number.isFinite(before) && before > price ? Math.round((before - price) / before * 100) : null;
    const key = digestKey(r.store, r.item_name, price);
    if (sent.has(key)) continue;
    const need = needs.some((n) => offerMatchesNeed(n, r.item_name));
    const favorite = favorites.some((f) => sameStoreName(f, r.store)) && (saving ?? 0) >= FAVORITE_MIN_SAVING;
    const fire = (saving ?? 0) >= FIRE_MIN_SAVING && bought.some((b) => offerMatchesNeed(b, r.item_name));
    const why = need ? "need" : favorite ? "favorite" : fire ? "fire" : null;
    if (!why) continue;
    const url = typeof r.source_url === "string" && /^https:\/\/\S{4,500}$/.test(r.source_url) ? r.source_url : null;
    scored.push({
      key, item: r.item_name, store: r.store, price, price_before: saving !== null ? before : null,
      currency: String(r.currency ?? ""), saving, why, url, source: r.source_kind,
      photo: digestPhoto(r.source_kind, r.source_url), until: r.valid_until ? r.valid_until.slice(0, 10) : null,
      rank: (why === "need" ? 0 : why === "favorite" ? 1000 : 2000) - (saving ?? 0),
    });
  }
  scored.sort((a, b) => a.rank - b.rank);
  const out: DigestCard[] = [];
  const items = new Set<string>();
  const perStore = new Map<string, number>();
  for (const { rank: _rank, ...card } of scored) {
    const ik = itemKey(card.item);
    const sk = codeStoreKey(card.store);
    if (items.has(ik) || (perStore.get(sk) ?? 0) >= 2) continue;
    items.add(ik);
    perStore.set(sk, (perStore.get(sk) ?? 0) + 1);
    out.push(card);
    if (out.length >= max) break;
  }
  return out;
}

/** أقل خصم يتبعت كـ«أقوى عروض الموسم» لبيت مالقيناش له حاجة شخصية. */
export const TOP_MIN_SAVING = 15;
export const TOP_MAX_DEALS = 3;

/**
 * لما مفيش ولا عرض على حاجة البيت أو محلاته (بيت جديد، قايمته أصناف بماركات مش في العروض، ومفيش معاملات تقول محلاته):
 * الرسالة كانت بتتلغي خالص، فالمالك ماجالوش ولا عرض في الجمعة البيضاء (مراجعة ٦/١١). دلوقتي أقوى الخصومات الحقيقية في بلده
 * (سعر قبل وبعد، ١٥٪ أو أكتر)، بنفس قواعد صنف مرة ومحلين بالكتير، واللي اتبعت مايتبعتش تاني.
 */
export function pickTopDeals(
  rows: readonly DigestDealRow[] | null | undefined,
  sent: ReadonlySet<string>,
  max = TOP_MAX_DEALS,
): DigestCard[] {
  const scored: DigestCard[] = [];
  for (const r of rows ?? []) {
    const price = Number(r.price);
    const before = Number(r.price_before);
    if (!r.store || !r.item_name || !Number.isFinite(price) || price <= 0 || !Number.isFinite(before) || before <= price) continue;
    const saving = Math.round((before - price) / before * 100);
    if (saving < TOP_MIN_SAVING || saving >= 90) continue;
    const key = digestKey(r.store, r.item_name, price);
    if (sent.has(key)) continue;
    const url = typeof r.source_url === "string" && /^https:\/\/\S{4,500}$/.test(r.source_url) ? r.source_url : null;
    scored.push({
      key, item: r.item_name, store: r.store, price, price_before: before, currency: String(r.currency ?? ""), saving,
      why: "top", url, source: r.source_kind, photo: digestPhoto(r.source_kind, r.source_url),
      until: r.valid_until ? r.valid_until.slice(0, 10) : null,
    });
  }
  // الصورة الأول (كارت بصورة أوضح على البوت)، بعدها الخصم الأكبر.
  scored.sort((a, b) => (b.photo ? 1 : 0) - (a.photo ? 1 : 0) || (b.saving ?? 0) - (a.saving ?? 0));
  const out: DigestCard[] = [];
  const items = new Set<string>();
  const perStore = new Map<string, number>();
  for (const card of scored) {
    const ik = itemKey(card.item);
    const sk = codeStoreKey(card.store);
    if (items.has(ik) || (perStore.get(sk) ?? 0) >= 2) continue;
    items.add(ik);
    perStore.set(sk, (perStore.get(sk) ?? 0) + 1);
    out.push(card);
    if (out.length >= max) break;
  }
  return out;
}

/** قيمة الكود للترتيب: النسبة، أو المبلغ كنسبة تقريبية من طلب ١٥٠ لو مالوش نسبة. */
function codeValue(r: DigestCodeRow): number {
  const pct = Number(r.discount_percent);
  if (Number.isFinite(pct) && pct > 0) return pct;
  const amount = Number(r.discount_amount);
  return Number.isFinite(amount) && amount > 0 ? Math.min(60, amount / 150 * 100) : 0;
}

/**
 * أكواد البيت بالترتيب الذكي (ZAD_PLAN ٥.٩، طلب المالك ٧/١١ «الذكاء يختار مش الإعدادات»):
 *   ٠. محلاته وتطبيقاته اللي بيطلب منها على طول ([favorites]، ٣ مرات في ٦٠ يوم) — زي الأول.
 *   ١. أي محل أو تطبيق دفع له ولو مرة في الـ٦٠ يوم ([merchants]).
 *   ٢. البيت بيطلب دليفري أصلاً (تاجر من تطبيقات التوصيل في البنك) ⇒ أقوى أكواد تطبيقات التوصيل، ولو مابيطلبش منها.
 * جوه كل درجة: الخصم الأكبر الأول. اللي اتبعت في الموسم مايتبعتش تاني. ده الاختيار للرسايل بس — صفحة «العروض» بتعرض كله.
 */
export function pickDigestCodes(
  rows: readonly DigestCodeRow[] | null | undefined,
  favorites: readonly string[],
  sent: ReadonlySet<string>,
  max = DIGEST_MAX_CODES,
  merchants: readonly string[] = [],
): DigestCodeRow[] {
  const fav = new Set(favorites.map(codeStoreKey).filter((k) => k.length >= 2));
  const paid = new Set(merchants.map(codeStoreKey).filter((k) => k.length >= 2));
  const ordersDelivery = merchants.some((m) => deliveryApp(m) !== null);
  const tier = (r: DigestCodeRow) =>
    fav.has(r.store_key) ? 0 : paid.has(r.store_key) ? 1 : ordersDelivery && deliveryApp(r.store) !== null ? 2 : null;
  const ranked = (rows ?? [])
    .map((r, i) => ({ r, i, t: tier(r) }))
    .filter((x) => x.t !== null && !sent.has(`code|${x.r.store_key}|${x.r.code}`))
    .sort((a, b) => a.t! - b.t! || codeValue(b.r) - codeValue(a.r) || a.i - b.i);
  const out: DigestCodeRow[] = [];
  const stores = new Set<string>();
  for (const { r } of ranked) {
    if (stores.has(r.store_key)) continue; // كود واحد لكل تطبيق في الرسالة
    stores.add(r.store_key);
    out.push(r);
    if (out.length >= max) break;
  }
  return out;
}

/** كام يوم قبل الموسم احتياجاته تبدأ تدخل اختيار العروض (قبل ما الأسعار تعلى). */
export const SEASON_LEAD_DAYS = 21;
/** أساسيات رمضان اللي بتعلى قبله — نفس قايمة upcomingSeasonInstruction. */
export const RAMADAN_NEEDS = ["تمر", "ياميش", "قمر الدين", "زيت", "سكر", "رز", "مكرونة"];
export const SCHOOL_NEEDS = ["شنطة مدرسة", "أدوات مدرسية", "كراسات", "زي مدرسي"];

/**
 * ٥.٩ — قبل الموسم بخطوة: رمضان جوه [SEASON_LEAD_DAYS] يوم ⇒ أساسياته احتياج (التمر والياميش دايماً، والباقي لو البيت
 * بيجيبه)؛ رجوع المدارس جوه نفس المدة ⇒ أدوات المدرسة، بس لبيت فيه عيال في سوق شباكه معروف (الخليج، زي eventAhead).
 * بتتضاف بعد الاحتياج الحقيقي (القايمة واللي هيخلص). نقي.
 */
export function seasonNeeds(input: {
  now: number;
  country: string;
  kidsCount: number | null | undefined;
  bought: readonly string[];
  schoolStarts: readonly string[];
}): string[] {
  const out: string[] = [];
  if (upcomingSeason(new Date(input.now), "UTC", SEASON_LEAD_DAYS)?.kind === "ramadan") {
    out.push(...RAMADAN_NEEDS.filter((n, i) => i < 3 || input.bought.some((b) => offerMatchesNeed(n, b))));
  }
  const ahead = (d: string) => {
    const t = Date.parse(`${d}T00:00:00Z`);
    return Number.isFinite(t) && t > input.now && t - input.now <= SEASON_LEAD_DAYS * 86_400_000;
  };
  if ((input.kidsCount ?? 0) > 0 && SCHOOL_WINDOW_MARKETS.has(input.country) && input.schoolStarts.some(ahead)) {
    out.push(...SCHOOL_NEEDS);
  }
  return out;
}

interface DealInputs {
  country: string;
  broke: boolean;
  needs: string[];
  favorites: string[];
  /** كل التجار اللي البيت دفع لهم في [FAVORITE_WINDOW_DAYS] — للأكواد الذكية. */
  merchants: string[];
  bought: string[];
  sent: Set<string>;
  deals: DigestDealRow[];
  codes: DigestCodeRow[];
}

/** اللي البيت محتاجه وبيشتري منه، وعروض وأكواد بلده الشغالة (من غير المصادر الموقوفة بالبلاغات، ٤.١٩). null = بلد مش معروف. */
async function loadDealInputs(sb: SupabaseClient, userId: string, now: number): Promise<DealInputs | null> {
  const family = await householdFamilyId(sb, userId);
  const [{ data: user }, { data: shop }, { data: home }, { data: txns }, { data: bought }, broke, { data: sentRows }] = await Promise.all([
    sb.from("zad_users").select("country,travel_country,travel_since").eq("id", userId).maybeSingle(),
    sb.from("zad_shopping_list").select("item_name").or(householdFilter(userId, family)).eq("is_purchased", false).limit(30),
    sb.from("zad_home_state").select("state").eq("user_id", userId).maybeSingle(),
    sb.from("zad_transactions").select("merchant_name").eq("user_id", userId).eq("txn_kind", "expense")
      .gte("created_at", new Date(now - FAVORITE_WINDOW_DAYS * 86_400_000).toISOString()).limit(500),
    sb.from("zad_inventory").select("item_name").or(householdFilter(userId, family)).limit(300),
    sb.from("zad_broke_mode").select("ends_at,ended_at").eq("user_id", userId).maybeSingle()
      .then((r) => r.error ? true : isBrokeModeActive(r.data as { ends_at?: string | null; ended_at?: string | null } | null, now), () => true),
    sb.from("zad_deal_digest_sent").select("deal_key").eq("user_id", userId).limit(500),
  ]);
  // ٥.٩: الموسم الجاي (رمضان، المدارس) — عيال البيت وشباك المدارس. فشل القراية = من غير موسم.
  const [{ data: profile }, { data: windows }] = await Promise.all([
    sb.from("zad_customer_profile").select("kids_count").eq("user_id", userId).maybeSingle().then((r) => r, () => ({ data: null })),
    sb.from("seasonal_event_windows").select("start_date,seasonal_events(slug)")
      .gte("start_date", new Date(now).toISOString().slice(0, 10)).limit(50).then((r) => r, () => ({ data: null })),
  ]);
  // ٥.٩: اللي بيفكر فيه — قاله («عايز أشتري») أو سأل عن سعره أو مكانه — احتياج زي القايمة. فشل القراية = من غيرها.
  const { data: intents } = await sb.from("zad_purchase_intents").select("item").eq("user_id", userId).eq("status", "open")
    .gt("expires_at", new Date(now).toISOString()).order("said_at", { ascending: false }).limit(5)
    .then((r) => r, () => ({ data: null }));
  const country = dealCountry(user as { country?: string | null; travel_country?: string | null; travel_since?: string | null } | null, now);
  if (!/^[A-Z]{2}$/.test(country)) return null;
  // ٧/١١: نشرات المناطق (الدانوب) بمدينتها — عرض مدينة تانية مايتبعتش (dealsForCity)، والأحدث الأول عشان الـ٤٠٠ مايتقطعوش عشوائي.
  const [{ data: deals }, { data: paused }, { data: codes }, city] = await Promise.all([
    sb.from("zad_deals").select("store,item_name,price,price_before,currency,source_kind,source_url,valid_until,city")
      .eq("country", country).gt("expires_at", new Date(now).toISOString()).order("found_at", { ascending: false }).limit(400),
    sb.rpc("zad_deal_paused_sources", { p_days: 14 }),
    sb.from("zad_deal_codes").select("store,store_key,code,discount_percent,discount_amount,currency,min_order,valid_until,source_kind,source_url")
      .eq("country", country).gt("expires_at", new Date(now).toISOString()).order("found_at", { ascending: false }).limit(100),
    customerCity(sb, userId, country).catch(() => ""),
  ]);
  const pausedKinds = new Set(((paused ?? []) as Array<{ source_kind: string }>).map((r) => r.source_kind));
  return {
    country,
    broke,
    needs: [
      ...((intents ?? []) as Array<{ item: string | null }>).map((r) => r.item ?? ""),
      ...((shop ?? []) as Array<{ item_name: string }>).map((r) => r.item_name),
      ...runningOutNames((home as { state?: unknown } | null)?.state),
      ...seasonNeeds({
        now, country,
        kidsCount: (profile as { kids_count?: number | null } | null)?.kids_count,
        bought: ((bought ?? []) as Array<{ item_name: string | null }>).map((r) => r.item_name ?? "").filter(Boolean),
        schoolStarts: ((windows ?? []) as Array<{ start_date: string; seasonal_events?: { slug?: string } | Array<{ slug?: string }> | null }>)
          .filter((w) => [w.seasonal_events].flat().some((e) => e?.slug === "back_to_school")).map((w) => w.start_date),
      }),
    ].filter(Boolean),
    favorites: favoriteStores((txns ?? []) as Array<{ merchant_name: string | null }>),
    merchants: [...new Set(((txns ?? []) as Array<{ merchant_name: string | null }>).map((t) => (t.merchant_name ?? "").trim()).filter(Boolean))],
    bought: ((bought ?? []) as Array<{ item_name: string | null }>).map((r) => r.item_name ?? "").filter(Boolean),
    sent: new Set(((sentRows ?? []) as Array<{ deal_key: string }>).map((r) => r.deal_key)),
    deals: dealsForCity((deals ?? []) as DigestDealRow[], city).filter((d) => !pausedKinds.has(d.source_kind)),
    codes: (codes ?? []) as DigestCodeRow[],
  };
}

/** كل اللي رسالة الموسم محتاجاه لعميل واحد، أو null (مفيش حاجة تستاهل، أو الفلوس ضيقة). */
export async function loadSeasonDigest(
  sb: SupabaseClient,
  userId: string,
  now = Date.now(),
): Promise<{ season: string; cards: DigestCard[]; codes: DigestCodeRow[] } | null> {
  const input = await loadDealInputs(sb, userId, now);
  if (!input || input.broke) return null;
  const { data: season } = await sb.rpc("zad_deal_season_name", { p_country: input.country });
  if (typeof season !== "string" || !season) return null;
  const personal = pickDigest(input.deals, input.needs, input.favorites, input.bought, input.sent);
  const cards = personal.length ? personal : pickTopDeals(input.deals, input.sent);
  const pickedCodes = pickDigestCodes(input.codes, input.favorites, input.sent, DIGEST_MAX_CODES, input.merchants);
  if (!cards.length && !pickedCodes.length) return null;
  return { season, cards, codes: pickedCodes };
}

/** أقصى عدد كروت في شريط العروض على الرئيسية. */
export const HOME_MAX_DEALS = 8;
export const HOME_MAX_CODES = 4;

/** كارت الرئيسية: عرض الكارت، ومعاه كود خصم المحل نفسه لو فيه واحد شغال. */
export interface HomeDealCard extends DigestCard {
  code: { code: string; percent: number | null; amount: number | null; currency: string | null } | null;
}

const numOrNull = (v: unknown) => {
  const n = Number(v);
  return v === null || v === undefined || v === "" || !Number.isFinite(n) ? null : n;
};

/**
 * شريط العروض على الرئيسية (طلب المالك ٤/١١): نفس اختيار رسالة الموسم (pickDigest — الاحتياج الأول) بس طول السنة، ومن غير
 * سجل «اتبعت» (الشريط بيتشاف كل مرة، مش رسالة بتتبعت مرة). كل كارت بياخد كود خصم محله لو فيه. «أنا مفلس» = عروض
 * الحاجات اللي البيت محتاجها فعلاً بس، من غير أكواد ولا عروض محلات.
 */
export function pickHomeDeals(
  input: Pick<DealInputs, "broke" | "needs" | "favorites" | "bought" | "deals" | "codes"> & { merchants?: string[] },
): { cards: HomeDealCard[]; codes: DigestCodeRow[] } {
  const none = new Set<string>();
  const personal = pickDigest(input.deals, input.needs, input.broke ? [] : input.favorites, input.broke ? [] : input.bought, none, HOME_MAX_DEALS);
  // مفيش حاجة شخصية ⇒ أقوى الخصومات الحقيقية في البلد، عشان الشريط مايختفيش عن بيت جديد (مراجعة ٦/١١). «أنا مفلس» ⇒ لأ.
  const picked = personal.length || input.broke ? personal : pickTopDeals(input.deals, none, HOME_MAX_DEALS);
  const cards = picked
    .filter((c) => !input.broke || c.why === "need")
    .map((c): HomeDealCard => {
      const k = input.broke ? undefined : input.codes.find((r) => sameStoreName(r.store, c.store));
      return {
        ...c,
        code: k
          ? { code: k.code, percent: numOrNull(k.discount_percent), amount: numOrNull(k.discount_amount), currency: k.currency }
          : null,
      };
    });
  if (input.broke) return { cards, codes: [] };
  const stores = [...input.favorites, ...cards.map((c) => c.store)];
  return { cards, codes: pickDigestCodes(input.codes, stores, none, HOME_MAX_CODES, input.merchants ?? []) };
}

/** شريط الرئيسية لعميل واحد. country null = بلده مش معروف (مفيش عروض تتعرض). */
export async function loadHomeDeals(
  sb: SupabaseClient,
  userId: string,
  now = Date.now(),
): Promise<{ country: string | null; cards: HomeDealCard[]; codes: DigestCodeRow[] }> {
  const input = await loadDealInputs(sb, userId, now);
  if (!input) return { country: null, cards: [], codes: [] };
  const picked = pickHomeDeals(input);
  const others = input.deals.map((d) => d.source_url ?? "").filter((u) => u && !picked.cards.some((c) => c.url === u));
  const cards = await withPagePreviews(sb, picked.cards, others);
  return { country: input.country, ...picked, cards };
}

/** صفحة اتقرت ومالقيناش فيها صورة بتتقرا تاني بعد كده بس (الصفحة ممكن تتحدث). */
const PREVIEW_RECHECK_MS = 7 * 86_400_000;
/** صفحات زيادة من عروض البلد بتتقرا في الخلفية كل مرة، عشان صفحة العروض تلحق. */
const PREVIEW_BACKGROUND = 8;

declare const EdgeRuntime: { waitUntil(p: Promise<unknown>): void } | undefined;

/**
 * الكروت من غير صورة بتاخد صورة صفحة عرضها (og:image، `_shared/pagePreview.ts`) من `zad_page_previews`، والصفحة اللي
 * ماتقرتش بتتقرا دلوقتي (٤ ثواني بالكتير، مع بعض). [others] = روابط عروض تانية في البلد: أول [PREVIEW_BACKGROUND]
 * منهم ماتقروش بيتقروا بعد الرد.
 */
export async function withPagePreviews(
  sb: SupabaseClient,
  cards: HomeDealCard[],
  others: readonly string[] = [],
  fetchImage: (url: string) => Promise<string | null> = (u) => fetchPreviewImage(u),
  now = Date.now(),
): Promise<HomeDealCard[]> {
  const wanted = [...new Set(cards.filter((c) => !c.photo && previewableUrl(c.url)).map((c) => c.url as string))];
  const extra = [...new Set(others.filter((u) => previewableUrl(u) && !wanted.includes(u)))].slice(0, 60);
  if (wanted.length === 0 && extra.length === 0) return cards;
  const { data } = await sb.from("zad_page_previews").select("url,image,checked_at").in("url", [...wanted, ...extra]);
  const known = new Map(((data ?? []) as Array<{ url: string; image: string | null; checked_at: string }>).map((r) => [r.url, r]));
  const stale = (u: string) => {
    const r = known.get(u);
    return !r || (!r.image && now - Date.parse(r.checked_at) > PREVIEW_RECHECK_MS);
  };
  const readAndStore = async (urls: string[]) => {
    const rows = await Promise.all(urls.map(async (url) => ({ url, image: await fetchImage(url), checked_at: new Date(now).toISOString() })));
    if (rows.length) await sb.from("zad_page_previews").upsert(rows, { onConflict: "url" }).then(() => {}, () => {});
    return rows;
  };
  for (const r of await readAndStore(wanted.filter(stale))) known.set(r.url, r);
  const later = extra.filter(stale).slice(0, PREVIEW_BACKGROUND);
  if (later.length) {
    const job = readAndStore(later).catch(() => []);
    if (typeof EdgeRuntime !== "undefined" && EdgeRuntime?.waitUntil) EdgeRuntime.waitUntil(job);
  }
  return cards.map((c) => c.photo || !c.url ? c : { ...c, photo: known.get(c.url)?.image ?? null });
}
