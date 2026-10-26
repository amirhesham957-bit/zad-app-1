/**
 * Admitad (ZAD_PLAN 4.5, the partner source): the network's coupons as rows for zad_deal_put.
 *
 * zad_deals is a price table — every row needs an item and its price. Most Admitad coupons are a store-wide
 * code («10% على كل الطلبات») with no item and no price, and those are skipped, not invented. A coupon
 * becomes a deal only when its title states a price in a currency we can tie to one of its regions.
 * The skip counts come back in the run's answer, so the first real run measures how many fit.
 *
 * Field names follow Admitad's public API docs (coupons/website/{w_id}); they have not been checked
 * against a live answer yet — this account had no credentials on 2026-10-26.
 */

export const ADMITAD_API = "https://api.admitad.com";

/** Partner rows are the store's own offer, but the price is read out of a title: just under a receipt. */
export const PARTNER_CONFIDENCE = 0.55;

/** The markets Zad sells in, with their currency. */
export const MARKET_CURRENCY: Readonly<Record<string, string>> = {
  SA: "SAR", EG: "EGP", AE: "AED", KW: "KWD", QA: "QAR", BH: "BHD", OM: "OMR", JO: "JOD",
};

// The words a price is written with in a title → the currencies they can mean. «ريال» alone is three
// markets; the coupon's regions pick one.
const CURRENCY_WORDS: ReadonlyArray<[RegExp, readonly string[]]> = [
  [/(?:SAR|ر\.?\s?س)/i, ["SAR"]],
  [/(?:EGP|ج\.?\s?م|جنيه)/i, ["EGP"]],
  [/(?:AED|د\.?\s?إ|درهم)/i, ["AED"]],
  [/(?:KWD|د\.?\s?ك)/i, ["KWD"]],
  [/(?:QAR|ر\.?\s?ق)/i, ["QAR"]],
  [/(?:BHD|د\.?\s?ب)/i, ["BHD"]],
  [/(?:OMR|ر\.?\s?ع)/i, ["OMR"]],
  [/(?:JOD|دينار)/i, ["JOD", "KWD", "BHD"]],
  [/ريال/, ["SAR", "QAR", "OMR"]],
];

export interface AdmitadCoupon {
  id?: number;
  name?: string;
  status?: string;
  regions?: string[];
  discount?: string | null;
  goto_link?: string;
  date_start?: string | null;
  date_end?: string | null;
  campaign?: { id?: number; name?: string } | null;
}

export type SkipReason =
  | "inactive" | "no_store" | "no_link" | "no_price" | "discount_not_price" | "no_market" | "ambiguous_market"
  | "already_over";

export type Mapped = { ok: true; payload: Record<string, unknown> } | { ok: false; reason: SkipReason };

/** Basic header for the client_credentials grant: base64(client_id:client_secret). */
export function basicHeader(clientId: string, clientSecret: string): string {
  return "Basic " + btoa(`${clientId}:${clientSecret}`);
}

/** Admitad writes "2026-10-31 23:59:59" with no zone; read as UTC. A bare date ends at its last second. */
export function admitadDate(raw: string | null | undefined, endOfDay = false): string | null {
  const s = (raw ?? "").trim();
  if (!/^\d{4}-\d{2}-\d{2}/.test(s)) return null;
  const iso = s.length > 10 ? s.replace(" ", "T") : `${s}T${endOfDay ? "23:59:59" : "00:00:00"}`;
  const ms = Date.parse(iso.endsWith("Z") ? iso : `${iso}Z`);
  return Number.isFinite(ms) ? new Date(ms).toISOString() : null;
}

const ARABIC_DIGITS = /[٠-٩]/g;
const toLatin = (s: string) => s.replace(ARABIC_DIGITS, (d) => String("٠١٢٣٤٥٦٧٨٩".indexOf(d))).replace(/٫/g, ".");
const NUMBER = String.raw`(\d+(?:[.,]\d{1,2})?)`;

/**
 * «زيت عافية ١٫٥ لتر بـ٢٥ ريال بدل ٣٢» → item, 25, 32, ["SAR","QAR","OMR"]. Anything with «خصم», «%» or
 * «off» is a discount on a basket, not a price, and is left out.
 */
export function priceFromTitle(title: string):
  | { item: string; price: number; before: number | null; currencies: readonly string[] }
  | { reason: "no_price" | "discount_not_price" } {
  const t = toLatin(title).replace(/\s+/g, " ").trim();
  if (/%|٪|خصم|\boff\b|discount/i.test(t)) return { reason: "discount_not_price" };
  for (const [word, currencies] of CURRENCY_WORDS) {
    const m = t.match(new RegExp(String.raw`(?:بـ\s?|ب\s|at\s|for\s)?${NUMBER}\s?(?:${word.source})`, "i"));
    if (!m || m.index === undefined) continue;
    const price = Number(m[1].replace(",", "."));
    if (!(price > 0)) continue;
    const before = t.match(new RegExp(String.raw`(?:بدل|بدلا من|was|instead of)\s?${NUMBER}`, "i"));
    const priceBefore = before ? Number(before[1].replace(",", ".")) : null;
    const item = t.slice(0, m.index).replace(/[\s\-–:،,]+$/u, "").trim();
    if (item.length < 2) return { reason: "no_price" };
    return { item: item.slice(0, 80), price, before: priceBefore && priceBefore > price ? priceBefore : null, currencies };
  }
  return { reason: "no_price" };
}

export function mapCoupon(c: AdmitadCoupon, nowMs: number): Mapped {
  if (c.status && c.status !== "active") return { ok: false, reason: "inactive" };
  const store = (c.campaign?.name ?? "").trim().slice(0, 60);
  if (!store) return { ok: false, reason: "no_store" };
  const link = (c.goto_link ?? "").trim();
  if (!/^https:\/\//.test(link) || link.length > 500) return { ok: false, reason: "no_link" };
  const until = admitadDate(c.date_end, true);
  if (until && Date.parse(until) <= nowMs) return { ok: false, reason: "already_over" };

  const parsed = priceFromTitle(c.name ?? "");
  if ("reason" in parsed) return { ok: false, reason: parsed.reason };

  const regions = (c.regions ?? []).map((r) => r.toUpperCase()).filter((r) => r in MARKET_CURRENCY);
  const markets = regions.filter((r) => parsed.currencies.includes(MARKET_CURRENCY[r]));
  if (!markets.length) return { ok: false, reason: "no_market" };
  if (markets.length > 1 && new Set(markets.map((r) => MARKET_CURRENCY[r])).size > 1) {
    return { ok: false, reason: "ambiguous_market" };
  }

  return {
    ok: true,
    payload: {
      country: markets[0],
      city: "",
      store,
      item_name: parsed.item,
      price: parsed.price,
      price_before: parsed.before,
      currency: MARKET_CURRENCY[markets[0]],
      deal_kind: parsed.before ? "discount" : "price",
      valid_from: admitadDate(c.date_start),
      valid_until: until,
      source_kind: "partner",
      source_url: link,
      confidence: PARTNER_CONFIDENCE,
    },
  };
}
