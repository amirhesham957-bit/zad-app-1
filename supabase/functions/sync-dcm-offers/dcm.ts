/**
 * DCMnetwork Codes Hub (ZAD_PLAN 4.5, the partner source): the coupons assigned to our account as rows for
 * zad_deal_put — the same rule as Admitad's (sync-admitad-offers/admitad.ts).
 *
 * The API is the one DCM's support sent on 2026-10-27 ("Publisher APIs", their Confluence helpdesk):
 *   GET https://api.dcmnetwork.com/affiliate-user/get-active-coupons/{DATA_API_KEY}?page=1&pageSize=50
 * The key sits in the path, so the URL is never logged. The page lists the data points by name only —
 * IdPK, brand, logo, coupon, coupon description, user terms, utime, sent_to_publisher_utime, countries,
 * website, app_link, web_link — not the JSON keys, so the reader below accepts the likely spellings and
 * the first dry run returns the real keys.
 *
 * zad_deals is a price table. A DCM coupon is mostly a store-wide code («Up to 10% Cashback»), which has no
 * item and no price: it is counted and skipped, never given an invented price. Only a description that
 * states a price in a currency of one of its countries becomes a deal.
 */

import { MARKET_CURRENCY, PARTNER_CONFIDENCE, priceFromTitle } from "../sync-admitad-offers/admitad.ts";
import type { CouponRow } from "./hasoffers.ts";

export const DCM_API = "https://api.dcmnetwork.com/affiliate-user";
export const DCM_PAGE_SIZE = 50;

export type DcmCoupon = Record<string, unknown>;

export type SkipReason =
  | "no_store" | "no_link" | "no_price" | "discount_not_price" | "no_market" | "ambiguous_market" | "already_over";

export type Mapped = { ok: true; payload: Record<string, unknown> } | { ok: false; reason: SkipReason };

/** The first non-empty string under any of [keys], matched without case, «_», «-» or spaces. */
export function field(c: DcmCoupon, ...keys: string[]): string {
  const norm = (k: string) => k.toLowerCase().replace(/[\s_-]/g, "");
  const wanted = new Set(keys.map(norm));
  for (const [k, v] of Object.entries(c)) {
    if (!wanted.has(norm(k))) continue;
    if (typeof v === "string" && v.trim()) return v.trim();
    if (typeof v === "number") return String(v);
    if (v && typeof v === "object" && !Array.isArray(v)) {
      const name = (v as Record<string, unknown>).name;
      if (typeof name === "string" && name.trim()) return name.trim();
    }
  }
  return "";
}

const COUNTRY_CODES: ReadonlyArray<[RegExp, string]> = [
  [/^(sa|ksa|saudi( arabia)?|السعودية)$/i, "SA"],
  [/^(ae|uae|united arab emirates|emirates|الإمارات|الامارات)$/i, "AE"],
  [/^(eg|egypt|مصر)$/i, "EG"],
  [/^(kw|kuwait|الكويت)$/i, "KW"],
  [/^(qa|qatar|قطر)$/i, "QA"],
  [/^(bh|bahrain|البحرين)$/i, "BH"],
  [/^(om|oman|عمان|عُمان)$/i, "OM"],
  [/^(jo|jordan|الأردن|الاردن)$/i, "JO"],
];

/** «UAE, KSA» / ["Saudi Arabia","Egypt"] → ["AE","SA"]: only the markets Zad sells in. */
export function countriesOf(raw: unknown): string[] {
  const parts = Array.isArray(raw)
    ? raw.map((x) => (typeof x === "string" ? x : String((x as { name?: unknown; code?: unknown })?.code ?? (x as { name?: unknown })?.name ?? "")))
    : typeof raw === "string" ? raw.split(/[,،|/;]+/) : [];
  const out: string[] = [];
  for (const p of parts) {
    const hit = COUNTRY_CODES.find(([re]) => re.test(p.trim()));
    if (hit && !out.includes(hit[1])) out.push(hit[1]);
  }
  return out;
}

/** «Valid until 30-12-2024» in the user terms → the end of that day, UTC. null when the terms name no date. */
export function validUntil(terms: string): string | null {
  const m = terms.match(/valid\s+(?:until|till|to)\s+(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})/i);
  if (!m) return null;
  const [d, mo, y] = [Number(m[1]), Number(m[2]), Number(m[3])];
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  const ms = Date.UTC(y, mo - 1, d, 23, 59, 59);
  return Number.isFinite(ms) ? new Date(ms).toISOString() : null;
}

export function mapCoupon(c: DcmCoupon, nowMs: number): Mapped {
  const store = field(c, "brand", "brand_name", "store", "store_name", "campaign", "campaign_name", "name").slice(0, 60);
  if (!store) return { ok: false, reason: "no_store" };
  // web_link is the tracked link (the commission); the bare website is not.
  const link = field(c, "web_link", "weblink", "tracking_url", "tracking_link", "link", "app_link");
  if (!/^https:\/\//.test(link) || link.length > 500) return { ok: false, reason: "no_link" };
  const terms = field(c, "user_terms", "terms", "terms_and_conditions", "conditions");
  const until = validUntil(terms);
  if (until && Date.parse(until) <= nowMs) return { ok: false, reason: "already_over" };

  const parsed = priceFromTitle(field(c, "coupon_desc", "coupon_description", "description", "desc", "title"));
  if ("reason" in parsed) return { ok: false, reason: parsed.reason };

  const countries = countriesOf(c.countries ?? c.country ?? c.Countries);
  const markets = countries.filter((r) => parsed.currencies.includes(MARKET_CURRENCY[r]));
  if (!markets.length) return { ok: false, reason: "no_market" };
  if (new Set(markets.map((r) => MARKET_CURRENCY[r])).size > 1) return { ok: false, reason: "ambiguous_market" };

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
      valid_until: until,
      source_kind: "partner",
      source_url: link,
      confidence: PARTNER_CONFIDENCE,
    },
  };
}

/** The coupons of one page, wherever the answer keeps them ({data:[…]}, {coupons:[…]}, {result:{data:[…]}} or a bare list). */
export function couponsOf(body: unknown): DcmCoupon[] {
  if (Array.isArray(body)) return body.filter((x) => x && typeof x === "object") as DcmCoupon[];
  if (!body || typeof body !== "object") return [];
  const o = body as Record<string, unknown>;
  for (const k of ["data", "coupons", "result", "results", "items", "rows"]) {
    const v = o[k];
    if (Array.isArray(v)) return couponsOf(v);
    if (v && typeof v === "object") {
      const inner = couponsOf(v);
      if (inner.length) return inner;
    }
  }
  return [];
}

/**
 * What the first page looked like, for the dry run: its top-level keys with their type (and a list's length),
 * and its first 600 characters with [key] cut out wherever it appears.
 */
export function describeAnswer(body: unknown, key: string): { shape: Record<string, string> | string; sample: string } {
  const kind = (v: unknown) => Array.isArray(v) ? `array(${v.length})` : v === null ? "null" : typeof v;
  const shape = body && typeof body === "object" && !Array.isArray(body)
    ? Object.fromEntries(Object.entries(body as Record<string, unknown>).map(([k, v]) => [k, kind(v)]))
    : kind(body);
  const raw = typeof body === "string" ? body : JSON.stringify(body) ?? "";
  const sample = (key ? raw.split(key).join("[key]") : raw).slice(0, 600);
  return { shape, sample };
}

/**
 * A Codes Hub coupon as zad_coupons rows, one per country (or one 'GLOBAL' when it names none). Unlike
 * mapCoupon, a store-wide code is kept: zad_coupons is where codes without a price belong. null when the
 * coupon has no id, store or tracked link, or its terms say it is over.
 */
export function couponRows(c: DcmCoupon, nowMs: number, syncedAt: string): CouponRow[] | null {
  const id = field(c, "IdPK", "id", "coupon_id").slice(0, 80);
  const store = field(c, "brand", "brand_name", "store", "store_name", "campaign", "campaign_name", "name").slice(0, 80);
  const link = field(c, "web_link", "weblink", "tracking_url", "tracking_link", "link", "app_link");
  if (!id || !store || !/^https:\/\//.test(link) || link.length > 1000) return null;
  const until = validUntil(field(c, "user_terms", "terms", "terms_and_conditions", "conditions"));
  if (until && Date.parse(until) <= nowMs) return null;
  const code = field(c, "coupon", "code", "coupon_code").slice(0, 60) || null;
  const logo = field(c, "logo", "logo_url", "image");
  const countries = countriesOf(c.countries ?? c.country ?? c.Countries);
  return (countries.length ? countries : ["GLOBAL"]).map((cc) => ({
    source: "dcm_coupon",
    external_id: id,
    country_code: cc,
    store,
    title: field(c, "coupon_desc", "coupon_description", "description", "desc", "title").slice(0, 200),
    code,
    category: null,
    click_url: link,
    logo_url: /^https:\/\//.test(logo) && logo.length <= 500 ? logo : null,
    payout_percent: null,
    payout_flat: null,
    payout_currency: null,
    is_trending: false,
    valid_until: until,
    active: true,
    synced_at: syncedAt,
  }));
}
