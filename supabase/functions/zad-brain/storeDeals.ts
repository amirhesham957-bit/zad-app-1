/**
 * The weekly store-deals search (ZAD_PLAN 4.3): what zad-core-intelligence's store_deals answered,
 * as rows for zad_deal_put. City '' is the store across the whole country; a target carries a city
 * when its customers' city is known (zad_user_city, found from their coarse point — 3/11).
 */

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

/** Stores searched in one run: ten a week stays far inside ZAD_SEARCH_DAILY_CAP. */
export const STORES_PER_RUN = 10;

/** Stores read on YouTube in one run (ZAD_PLAN 4.11): a video read is tens of seconds, the run has 120. */
export const YOUTUBE_STORES_PER_RUN = 3;

/**
 * Stores read on Instagram in one run (ZAD_PLAN 4.12): three posts a store with their pictures. The account may look
 * up 30 new hashtags in 7 days and the probe spends one, so the weekly cron's six runs stop at 18 stores.
 */
export const INSTAGRAM_STORES_PER_RUN = 3;

/** A searched offer is a web page read by a model: below a receipt floor (0.6 at 3 homes). */
export const SEARCH_CONFIDENCE = 0.5;

/** An offer read off the store's own official flyer (the bot's flyer path uses the same 0.7). */
export const FLYER_CONFIDENCE = 0.7;

/** A flyer that failed is tried again after this, not on every run. */
export const FLYER_RETRY_HOURS = 20;

export interface FlyerEntryRow { store: string; country: string; currency: string; label: string; pdf_url: string; city: string }
export interface FlyerReadRow { pdf_url: string; ok: boolean; read_at: string }

/**
 * Official flyers (zad-core-intelligence/officialFlyers.ts): the sites' answer to «list» flattened, and the first flyer
 * not read yet — a flyer read once (ok) is never read again (a new flyer comes with a new link), and a failed one waits
 * [FLYER_RETRY_HOURS]. Weekly flyers before two-week ones: smaller, and fresher.
 */
export function flyerEntries(reply: unknown): FlyerEntryRow[] {
  const sites = reply && typeof reply === "object" ? (reply as { sites?: unknown }).sites : null;
  if (!Array.isArray(sites)) return [];
  const out: FlyerEntryRow[] = [];
  for (const s of sites) {
    if (!s || typeof s !== "object" || (s as { ok?: unknown }).ok !== true) continue;
    const { store, country, currency, entries } = s as Record<string, unknown>;
    if (typeof store !== "string" || typeof country !== "string" || typeof currency !== "string" || !Array.isArray(entries)) continue;
    for (const e of entries) {
      const r = e as Record<string, unknown>;
      if (typeof r?.pdf_url !== "string" || !r.pdf_url.startsWith("https://")) continue;
      out.push({
        store, country, currency,
        label: typeof r.label === "string" ? r.label : "",
        pdf_url: r.pdf_url,
        city: typeof r.city === "string" ? r.city : "",
      });
    }
  }
  return out;
}

export function nextFlyer(entries: FlyerEntryRow[], reads: FlyerReadRow[], now: Date): FlyerEntryRow | null {
  const last = new Map(reads.map((r) => [r.pdf_url, r]));
  const due = entries.filter((e) => {
    const r = last.get(e.pdf_url);
    if (!r) return true;
    if (r.ok) return false;
    return now.getTime() - new Date(r.read_at).getTime() >= FLYER_RETRY_HOURS * 3_600_000;
  });
  const weekly = (e: FlyerEntryRow) => /الاسبوعية|الأسبوعية|weekly/i.test(e.label) ? 0 : 1;
  due.sort((a, b) => weekly(a) - weekly(b));
  return due[0] ?? null;
}

/** Customers whose city is looked up in one run: LocationIQ's free tier is 2 a second, so one a second. */
export const CITIES_PER_RUN = 10;

export interface DealTarget { country: string; store: string; currency: string; city?: string }

export interface SearchedDeal {
  item_name: string;
  price: number;
  price_before: number | null;
  valid_until: string | null;
  source_url: string;
}

export function dealPutPayload(target: DealTarget, deal: SearchedDeal, sourceKind: "search" | "youtube" | "instagram" | "flyer" = "search"): Record<string, unknown> {
  return {
    country: target.country,
    city: target.city ?? "",
    store: target.store,
    item_name: deal.item_name,
    price: deal.price,
    price_before: deal.price_before,
    currency: target.currency,
    deal_kind: deal.price_before !== null ? "discount" : "price",
    valid_until: deal.valid_until,
    source_kind: sourceKind,
    source_url: deal.source_url,
    confidence: sourceKind === "flyer" ? FLYER_CONFIDENCE : SEARCH_CONFIDENCE,
  };
}

/**
 * A section heading read as an item (ZAD_PLAN 4.19, the 29/10 search reviewed by hand on 2/11): «أجهزة» at 5,099 from
 * Noon and «عروض الآيس كريم والحلويات الباردة» at 5.75 from Amazon. Neither is something a home can buy at that price.
 */
const NOT_AN_ITEM = /^\s*(عروض|عرض|خصومات|خصم|تخفيضات|تخفيض|اوكازيون|أوكازيون|offers?|deals?|sale)(\s|$)|^\s*(أجهزة|اجهزة|إلكترونيات|الكترونيات|منتجات|مستلزمات|أدوات|ادوات|electronics|appliances)\s*$/i;

/** store_deals' answer, kept only when it is the shape that service promises and names one item at a real price. */
export function searchedDeals(reply: unknown): SearchedDeal[] {
  const deals = reply && typeof reply === "object" ? (reply as { deals?: unknown }).deals : null;
  if (!Array.isArray(deals)) return [];
  return deals.filter((d): d is SearchedDeal =>
    !!d && typeof d === "object" &&
    typeof (d as SearchedDeal).item_name === "string" &&
    typeof (d as SearchedDeal).price === "number" &&
    (d as SearchedDeal).price > 0 &&
    typeof (d as SearchedDeal).source_url === "string" &&
    !NOT_AN_ITEM.test((d as SearchedDeal).item_name)
  );
}

/** place_city's answer: ok with a city ('' = none there), other_country, or a failure (retried next run). */
export type CityAnswer = { ok?: boolean; city?: unknown; other_country?: boolean } | null;

/**
 * ٤.٣: مدينة كل عميل محتاج مدينة (zad_users_needing_city) من نقطته المقرّبة، وبتتخزن في zad_user_city اسم بس.
 * فشل المزوّد مابيتسجّلش (يتجرب النداء الجاي)؛ نقطة برّه بلد الحساب مابتغيّرش المدينة اللي فاتت. بيرجع عدد اللي اتسجلوا.
 */
export async function findCustomerCities(
  sb: SupabaseClient,
  ask: (p: { lat: number; lon: number; country: string }) => Promise<CityAnswer>,
  opts: { limit?: number; pauseMs?: number; now?: () => Date } = {},
): Promise<number> {
  const { data, error } = await sb.rpc("zad_users_needing_city", { p_limit: opts.limit ?? CITIES_PER_RUN });
  if (error) {
    console.error("[deals_search_run] cities failed:", error.message);
    return 0;
  }
  const pause = opts.pauseMs ?? 1000;
  let saved = 0;
  const rows = (data ?? []) as Array<{ user_id: string; country: string; lat: number; lon: number }>;
  for (const [i, u] of rows.entries()) {
    if (i > 0 && pause > 0) await new Promise((r) => setTimeout(r, pause));
    const reply = await ask({ lat: u.lat, lon: u.lon, country: u.country }).catch(() => null);
    if (!reply?.ok || reply.other_country) continue;
    const city = typeof reply.city === "string" ? reply.city.trim().slice(0, 60) : "";
    const { error: upErr } = await sb.from("zad_user_city").upsert(
      { user_id: u.user_id, country: u.country, city, found_at: (opts.now?.() ?? new Date()).toISOString() },
      { onConflict: "user_id" },
    );
    if (upErr) console.error("[deals_search_run] city save failed:", upErr.message);
    else saved++;
  }
  return saved;
}
