/**
 * The weekly store-deals search (ZAD_PLAN 4.3): what zad-core-intelligence's store_deals answered,
 * as rows for zad_deal_put. City '' is the store across the whole country — accounts carry no city.
 */

/** Stores searched in one run: ten a week stays far inside ZAD_SEARCH_DAILY_CAP. */
export const STORES_PER_RUN = 10;

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

export function dealPutPayload(target: DealTarget, deal: SearchedDeal): Record<string, unknown> {
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
    source_kind: "search",
    source_url: deal.source_url,
    confidence: SEARCH_CONFIDENCE,
  };
}

/** store_deals' answer, kept only when it is the shape that service promises. */
export function searchedDeals(reply: unknown): SearchedDeal[] {
  const deals = reply && typeof reply === "object" ? (reply as { deals?: unknown }).deals : null;
  if (!Array.isArray(deals)) return [];
  return deals.filter((d): d is SearchedDeal =>
    !!d && typeof d === "object" &&
    typeof (d as SearchedDeal).item_name === "string" &&
    typeof (d as SearchedDeal).price === "number" &&
    typeof (d as SearchedDeal).source_url === "string"
  );
}
