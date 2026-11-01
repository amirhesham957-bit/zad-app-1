/**
 * DCMnetwork's HasOffers (TUNE) Affiliate API: the offers approved for our account as zad_coupons rows, one per
 * target country (ZAD_PLAN 4.5).
 *
 *   GET https://{DCM_NETWORK_ID}.api.hasoffers.com/Apiv3/json?api_key=…&Target=Affiliate_Offer&Method=findAll
 *
 * The key is a query parameter and HasOffers echoes it back under `request`, so neither a URL nor a raw
 * answer is ever logged. Shapes below were read off real answers on 2026-11-01, not from the docs:
 *   findAll             → response.data.data["685"].Offer {id, name, percent_payout, default_payout, payout_type, currency, featured, status, approval_status, …}
 *   getTargetCountries  → response.data[] {offer_id, countries: {"AE": {code, name}}}   (an offer with none is absent)
 *   getCategories       → response.data[] {offer_id, categories: {"26": {name}}}
 *   getThumbnail        → response.data[] {offer_id, Thumbnail: {"105029": {url, thumbnail}}}
 *   generateTrackingLink→ response.data {click_url, message}; click_url "" + «Must accept offer terms…» until the
 *                         offer's terms are accepted in the panel.
 */

export const TRENDING_PER_COUNTRY = 5;

export type Offer = {
  id: string;
  store: string;
  title: string;
  payoutPercent: number | null;
  payoutFlat: number | null;
  payoutCurrency: string | null;
  featuredAt: string | null;
};

export type CouponRow = {
  source: "dcm_offer" | "dcm_coupon";
  external_id: string;
  country_code: string;
  store: string;
  title: string;
  code: string | null;
  category: string | null;
  click_url: string | null;
  logo_url: string | null;
  payout_percent: number | null;
  payout_flat: number | null;
  payout_currency: string | null;
  is_trending: boolean;
  valid_until: string | null;
  active: boolean;
  synced_at: string;
};

export function apiUrl(networkId: string, key: string, target: string, method: string, params: Record<string, string | string[]> = {}): string {
  const q = new URLSearchParams({ api_key: key, Target: target, Method: method });
  for (const [k, v] of Object.entries(params)) {
    for (const one of Array.isArray(v) ? v : [v]) q.append(k, one);
  }
  return `https://${encodeURIComponent(networkId)}.api.hasoffers.com/Apiv3/json?${q}`;
}

/** response.data of a HasOffers answer, or the reason it has none. */
export function dataOf(body: unknown): { ok: true; data: unknown } | { ok: false; error: string } {
  const r = (body as { response?: { status?: unknown; data?: unknown; errors?: unknown; errorMessage?: unknown } })?.response;
  if (!r) return { ok: false, error: "no_response" };
  if (Number(r.status) !== 1) {
    const first = Array.isArray(r.errors) ? (r.errors[0] as { publicMessage?: unknown; err_msg?: unknown }) : undefined;
    return { ok: false, error: String(first?.publicMessage ?? first?.err_msg ?? r.errorMessage ?? "status_not_1").slice(0, 200) };
  }
  return { ok: true, data: r.data };
}

function num(v: unknown): number | null {
  const n = Number(v);
  return Number.isFinite(n) && n > 0 ? n : null;
}

/** «Amazon | UAE | Links» → «Amazon»: the store before the first «|». */
export function storeOf(name: string): string {
  return (name.split("|")[0] ?? "").trim().slice(0, 80);
}

/** The active, approved offers of a findAll answer. */
export function offersOf(data: unknown): Offer[] {
  const rows = (data as { data?: Record<string, { Offer?: Record<string, unknown> }> })?.data;
  if (!rows || typeof rows !== "object") return [];
  const out: Offer[] = [];
  for (const v of Object.values(rows)) {
    const o = v?.Offer;
    if (!o || o.status !== "active" || o.approval_status !== "approved") continue;
    const name = String(o.name ?? "");
    const store = storeOf(name);
    if (!store || !o.id) continue;
    const flat = o.payout_type === "cpa_flat";
    const currency = typeof o.currency === "string" && /^[A-Z]{3}$/.test(o.currency) ? o.currency : null;
    const featured = typeof o.featured === "string" && /^\d{4}-\d{2}-\d{2}/.test(o.featured) && !o.featured.startsWith("0000")
      ? o.featured : null;
    out.push({
      id: String(o.id),
      store,
      title: name.slice(0, 200),
      payoutPercent: flat ? null : num(o.percent_payout),
      payoutFlat: flat ? num(o.default_payout) : null,
      payoutCurrency: flat ? currency : null,
      featuredAt: featured,
    });
  }
  return out;
}

/** getTargetCountries → offer id → ISO codes. An offer missing from the answer targets no country. */
export function countriesByOffer(data: unknown): Map<string, string[]> {
  const out = new Map<string, string[]>();
  for (const row of Array.isArray(data) ? data : []) {
    const id = String((row as { offer_id?: unknown })?.offer_id ?? "");
    const countries = (row as { countries?: Record<string, { code?: unknown }> })?.countries;
    if (!id || !countries || typeof countries !== "object") continue;
    const codes = Object.values(countries)
      .map((c) => String(c?.code ?? "").toUpperCase())
      .filter((c) => /^[A-Z]{2}$/.test(c));
    if (codes.length) out.set(id, [...new Set(codes)]);
  }
  return out;
}

/** getCategories → offer id → its first category name («Departmental Store», «Beauty»…). */
export function categoryByOffer(data: unknown): Map<string, string> {
  const out = new Map<string, string>();
  for (const row of Array.isArray(data) ? data : []) {
    const id = String((row as { offer_id?: unknown })?.offer_id ?? "");
    const cats = (row as { categories?: Record<string, { name?: unknown }> })?.categories;
    if (!id || !cats || typeof cats !== "object") continue;
    const names = Object.values(cats).map((c) => String(c?.name ?? "").trim()).filter(Boolean);
    if (names.length) out.set(id, names[0].slice(0, 60));
  }
  return out;
}

/** getThumbnail → offer id → the first square https logo (the 100px copy when there is one). */
export function logoByOffer(data: unknown): Map<string, string> {
  const out = new Map<string, string>();
  for (const row of Array.isArray(data) ? data : []) {
    const id = String((row as { offer_id?: unknown })?.offer_id ?? "");
    const files = (row as { Thumbnail?: Record<string, { url?: unknown; thumbnail?: unknown; width?: unknown; height?: unknown }> })?.Thumbnail;
    if (!id || !files || typeof files !== "object") continue;
    const list = Object.values(files);
    const square = list.find((f) => f?.width && f.width === f.height) ?? list[0];
    const url = String(square?.thumbnail ?? square?.url ?? "");
    if (url.startsWith("https://")) out.set(id, encodeURI(decodeURI(url)).slice(0, 500));
  }
  return out;
}

/** generateTrackingLink → the tracked link, or why there is none («needs_terms» until the terms are accepted). */
export function trackingLinkOf(data: unknown): { url: string } | { reason: "needs_terms" | "no_link" } {
  const d = data as { click_url?: unknown; message?: unknown };
  const url = typeof d?.click_url === "string" ? d.click_url.trim() : "";
  if (url.startsWith("https://") && url.length <= 1000) return { url };
  if (url.startsWith("http://") && url.length <= 999) return { url: "https://" + url.slice(7) };
  return { reason: /terms and conditions/i.test(String(d?.message ?? "")) ? "needs_terms" : "no_link" };
}

/** One row per target country, or one 'GLOBAL' row for an offer that targets none. */
export function offerRows(
  offers: Offer[],
  countries: Map<string, string[]>,
  categories: Map<string, string>,
  logos: Map<string, string>,
  links: Map<string, string>,
  syncedAt: string,
): CouponRow[] {
  const rows: CouponRow[] = [];
  for (const o of offers) {
    for (const cc of countries.get(o.id) ?? ["GLOBAL"]) {
      rows.push({
        source: "dcm_offer",
        external_id: o.id,
        country_code: cc,
        store: o.store,
        title: o.title,
        code: null,
        category: categories.get(o.id) ?? null,
        click_url: links.get(o.id) ?? null,
        logo_url: logos.get(o.id) ?? null,
        payout_percent: o.payoutPercent,
        payout_flat: o.payoutFlat,
        payout_currency: o.payoutCurrency,
        is_trending: false,
        valid_until: null,
        active: true,
        synced_at: syncedAt,
      });
    }
  }
  return markTrending(rows, offers);
}

/**
 * Trending = the highest-commission offers we can actually link, per country: the top [perCountry] by percent
 * commission among rows with a click_url, ties to the one the network featured most recently. We have no
 * conversion data yet (a new account), so commission is the only measure; flat payouts are in mixed
 * currencies and are left out of the ranking rather than guessed at.
 */
export function markTrending(rows: CouponRow[], offers: Offer[], perCountry = TRENDING_PER_COUNTRY): CouponRow[] {
  const featured = new Map(offers.map((o) => [o.id, o.featuredAt ?? ""]));
  const byCountry = new Map<string, CouponRow[]>();
  for (const r of rows) {
    if (!r.click_url || r.payout_percent === null) continue;
    byCountry.set(r.country_code, [...(byCountry.get(r.country_code) ?? []), r]);
  }
  const top = new Set<CouponRow>();
  for (const list of byCountry.values()) {
    list
      .sort((a, b) =>
        (b.payout_percent ?? 0) - (a.payout_percent ?? 0) ||
        (featured.get(b.external_id) ?? "").localeCompare(featured.get(a.external_id) ?? ""))
      .slice(0, perCountry)
      .forEach((r) => top.add(r));
  }
  return rows.map((r) => (top.has(r) ? { ...r, is_trending: true } : r));
}
