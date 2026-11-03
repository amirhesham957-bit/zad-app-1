/**
 * The weekly store-deals search (ZAD_PLAN 4.3): what zad-core-intelligence's store_deals answered,
 * as rows for zad_deal_put. City '' is the store across the whole country — accounts carry no city.
 */

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

export interface DealTarget { country: string; store: string; currency: string }

export interface SearchedDeal {
  item_name: string;
  price: number;
  price_before: number | null;
  valid_until: string | null;
  source_url: string;
}

export function dealPutPayload(target: DealTarget, deal: SearchedDeal, sourceKind: "search" | "youtube" | "instagram" = "search"): Record<string, unknown> {
  return {
    country: target.country,
    city: "",
    store: target.store,
    item_name: deal.item_name,
    price: deal.price,
    price_before: deal.price_before,
    currency: target.currency,
    deal_kind: deal.price_before !== null ? "discount" : "price",
    valid_until: deal.valid_until,
    source_kind: sourceKind,
    source_url: deal.source_url,
    confidence: SEARCH_CONFIDENCE,
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
