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
import { dealCountry, FAVORITE_WINDOW_DAYS, favoriteStores, runningOutNames } from "./tasteDeals.ts";

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
}

export interface DigestCard {
  key: string;
  item: string;
  store: string;
  price: number;
  price_before: number | null;
  currency: string;
  saving: number | null;
  why: "need" | "favorite" | "fire";
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

/** أكواد تطبيقات ومحلات البيت، الأحدث الأول، اللي ماتبعتتش في الموسم. */
export function pickDigestCodes(
  rows: readonly DigestCodeRow[] | null | undefined,
  favorites: readonly string[],
  sent: ReadonlySet<string>,
  max = DIGEST_MAX_CODES,
): DigestCodeRow[] {
  const keys = new Set(favorites.map(codeStoreKey).filter((k) => k.length >= 2));
  return (rows ?? []).filter((r) => keys.has(r.store_key) && !sent.has(`code|${r.store_key}|${r.code}`)).slice(0, max);
}

/** كل اللي رسالة الموسم محتاجاه لعميل واحد، أو null (مفيش حاجة تستاهل، أو الفلوس ضيقة). */
export async function loadSeasonDigest(
  sb: SupabaseClient,
  userId: string,
  now = Date.now(),
): Promise<{ season: string; cards: DigestCard[]; codes: DigestCodeRow[] } | null> {
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
  if (broke) return null;
  const country = dealCountry(user as { country?: string | null; travel_country?: string | null; travel_since?: string | null } | null, now);
  if (!/^[A-Z]{2}$/.test(country)) return null;
  const { data: season } = await sb.rpc("zad_deal_season_name", { p_country: country });
  if (typeof season !== "string" || !season) return null;
  const needs = [
    ...((shop ?? []) as Array<{ item_name: string }>).map((r) => r.item_name),
    ...runningOutNames((home as { state?: unknown } | null)?.state),
  ].filter(Boolean);
  const favorites = favoriteStores((txns ?? []) as Array<{ merchant_name: string | null }>);
  const boughtNames = ((bought ?? []) as Array<{ item_name: string | null }>).map((r) => r.item_name ?? "").filter(Boolean);
  const sent = new Set(((sentRows ?? []) as Array<{ deal_key: string }>).map((r) => r.deal_key));
  const [{ data: deals }, { data: paused }, { data: codes }] = await Promise.all([
    sb.from("zad_deals").select("store,item_name,price,price_before,currency,source_kind,source_url,valid_until")
      .eq("country", country).gt("expires_at", new Date(now).toISOString()).limit(400),
    sb.rpc("zad_deal_paused_sources", { p_days: 14 }),
    sb.from("zad_deal_codes").select("store,store_key,code,discount_percent,discount_amount,currency,min_order,valid_until,source_kind,source_url")
      .eq("country", country).gt("expires_at", new Date(now).toISOString()).order("found_at", { ascending: false }).limit(100),
  ]);
  const pausedKinds = new Set(((paused ?? []) as Array<{ source_kind: string }>).map((r) => r.source_kind));
  const live = ((deals ?? []) as DigestDealRow[]).filter((d) => !pausedKinds.has(d.source_kind));
  const cards = pickDigest(live, needs, favorites, boughtNames, sent);
  const pickedCodes = pickDigestCodes(codes as DigestCodeRow[] | null, favorites, sent);
  if (!cards.length && !pickedCodes.length) return null;
  return { season, cards, codes: pickedCodes };
}
