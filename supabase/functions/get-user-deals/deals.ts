/**
 * get-user-deals' rules, kept pure for the tests: which country a customer gets, and the two lists.
 */

export const TRENDING_LIMIT = 10;
export const COUPONS_LIMIT = 100;

export type DealRow = {
  source: string;
  external_id: string;
  country_code: string;
  store: string;
  title: string;
  code: string | null;
  category: string | null;
  click_url: string;
  logo_url: string | null;
  payout_percent: number | null;
  is_trending: boolean;
  valid_until: string | null;
};

const ISO2 = /^[A-Z]{2}$/;

/**
 * The country to show: an explicit ?country= first, then the country the customer is travelling in (ZAD_PLAN
 * 3.14 — the stores around them), then the account's. null when none is a two-letter code.
 */
export function resolveCountry(
  param: string | null,
  user: { country?: string | null; travel_country?: string | null } | null,
): string | null {
  for (const raw of [param, user?.travel_country, user?.country]) {
    const cc = (raw ?? "").trim().toUpperCase();
    if (ISO2.test(cc)) return cc;
  }
  return null;
}

function byValue(a: DealRow, b: DealRow): number {
  return Number(!!b.code) - Number(!!a.code) || (b.payout_percent ?? 0) - (a.payout_percent ?? 0) ||
    a.store.localeCompare(b.store);
}

/**
 * [rows] are the live rows of [country] and of GLOBAL. The country's own rows when it has any; otherwise the
 * GLOBAL ones and fallback "global" — never another country's stores, which would not ship to the customer.
 */
export function shapeDeals(rows: DealRow[], country: string | null) {
  const own = country ? rows.filter((r) => r.country_code === country) : [];
  const fallback = own.length ? null : "global";
  const shown = own.length ? [...own, ...rows.filter((r) => r.country_code === "GLOBAL")] : rows.filter((r) => r.country_code === "GLOBAL");
  return {
    country,
    fallback,
    trending_deals: shown.filter((r) => r.is_trending).sort(byValue).slice(0, TRENDING_LIMIT),
    available_coupons: [...shown].sort(byValue).slice(0, COUPONS_LIMIT),
  };
}
