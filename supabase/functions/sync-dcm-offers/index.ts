// sync-dcm-offers — DCMnetwork for our account (ZAD_PLAN 4.5), two passes:
//   1. Codes Hub coupons ⇒ zad_deal_put when the description states a price (source_kind 'partner'), and every
//      coupon ⇒ zad_coupons (source 'dcm_coupon') with its code and countries.
//   2. HasOffers offers (hasoffers.ts) ⇒ zad_coupons (source 'dcm_offer'), one row per target country, the
//      highest-commission linked ones per country flagged is_trending. Skipped when DCM_MAIN_API_KEY is unset.
// A row this run did not see is turned inactive — only for a source whose fetch succeeded.
//
// Secrets: DCM_API_KEY or DCM_COUPONS_API_KEY (the "Data API Key" under Account > User Details & API Key on partner.dcmnetwork.com,
// already set on the project), DCM_MAIN_API_KEY (the HasOffers affiliate API key), DCM_NETWORK_ID (default
// "dcm"), and DCM_SYNC_CRON_SECRET against the X-Dcm-Cron-Secret header. ?dry=1 maps and counts without
// writing, and returns the first coupon's keys so the field names get checked against a real answer — the
// first run should be one.
//
// Only the official API DCM's support sent (dcm.ts). The portal-session route stays frozen (owner's
// decision, 2026-10-26). No cron calls this yet: one dry run first (net.http_post with ?dry=1 and the proactive secret).

import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { secretMatches } from "../_shared/cronSecret.ts";
import { couponRows, couponsOf, DCM_API, DCM_PAGE_SIZE, type DcmCoupon, describeAnswer, mapCoupon } from "./dcm.ts";
import {
  apiUrl, categoryByOffer, countriesByOffer, type CouponRow, dataOf, logoByOffer, offerRows, offersOf, trackingLinkOf,
} from "./hasoffers.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const MAX_PAGES = 20;
// generateTrackingLink is one call per offer; a link once made is kept, so only new offers cost a call.
const MAX_LINK_CALLS = 100;

type OffersPass =
  | { ok: true; rows: CouponRow[]; offers: number; linked: number; needsTerms: number }
  | { ok: false; error: string };

/** HasOffers: approved offers ⇒ zad_coupons rows. The key rides in the URL and in the echoed answer: log neither. */
async function offersPass(
  sb: SupabaseClient, networkId: string, key: string, syncedAt: string,
): Promise<OffersPass> {
  const call = async (target: string, method: string, params: Record<string, string | string[]> = {}) => {
    const res = await fetch(apiUrl(networkId, key, target, method, params), { signal: AbortSignal.timeout(20_000) });
    if (!res.ok) return { ok: false as const, error: `http_${res.status}` };
    try {
      return dataOf(await res.json());
    } catch {
      return { ok: false as const, error: "not_json" };
    }
  };

  const all = await call("Affiliate_Offer", "findAll", { limit: "1000" });
  if (!all.ok) return { ok: false, error: `findAll: ${all.error}` };
  const offers = offersOf(all.data);
  const ids = offers.map((o) => `${o.id}`);
  if (!ids.length) return { ok: true, rows: [], offers: 0, linked: 0, needsTerms: 0 };

  const [countries, categories, logos] = await Promise.all([
    call("Affiliate_Offer", "getTargetCountries", { "ids[]": ids }),
    call("Affiliate_Offer", "getCategories", { "ids[]": ids }),
    call("Affiliate_Offer", "getThumbnail", { "ids[]": ids }),
  ]);
  // Countries decide who sees an offer: without them every offer would land as GLOBAL. Stop instead.
  if (!countries.ok) return { ok: false, error: `getTargetCountries: ${countries.error}` };

  const links = new Map<string, string>();
  const { data: kept } = await sb.from("zad_coupons").select("external_id,click_url")
    .eq("source", "dcm_offer").not("click_url", "is", null);
  for (const r of (kept ?? []) as Array<{ external_id: string; click_url: string }>) links.set(r.external_id, r.click_url);

  let calls = 0;
  let needsTerms = 0;
  for (const o of offers) {
    if (links.has(o.id) || calls >= MAX_LINK_CALLS) continue;
    calls++;
    const got = await call("Affiliate_Offer", "generateTrackingLink", { offer_id: o.id });
    if (!got.ok) continue;
    const link = trackingLinkOf(got.data);
    if ("url" in link) links.set(o.id, link.url);
    else if (link.reason === "needs_terms") needsTerms++;
  }

  const rows = offerRows(
    offers,
    countriesByOffer(countries.data),
    categories.ok ? categoryByOffer(categories.data) : new Map(),
    logos.ok ? logoByOffer(logos.data) : new Map(),
    links,
    syncedAt,
  );
  return { ok: true, rows, offers: offers.length, linked: offers.filter((o) => links.has(o.id)).length, needsTerms };
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

Deno.serve(async (req) => {
  // The project's own cron secret works too (ZAD_PLAN 4.5, 3/11): it is already in the vault, so pg_cron and the first
  // dry run can call this the way they call zad-brain, without a second secret copied by hand.
  // Only the header that came is checked, so the other one's absence is not logged as a rejection.
  const proactive = req.headers.get("ZAD-PROACTIVE-CRON-SECRET");
  const authorized = proactive !== null
    ? await secretMatches(proactive, "ZAD_PROACTIVE_CRON_SECRET")
    : await secretMatches(req.headers.get("X-Dcm-Cron-Secret"), "DCM_SYNC_CRON_SECRET");
  if (!authorized) return json({ error: "unauthorized" }, 401);
  const dry = new URL(req.url).searchParams.get("dry") === "1";
  const key = (Deno.env.get("DCM_API_KEY") || Deno.env.get("DCM_COUPONS_API_KEY") || "").trim();
  if (!key) return json({ error: "no_api_key" }, 500);

  const coupons: DcmCoupon[] = [];
  let couponsError: string | null = null;
  // Zero coupons can mean none assigned, an answer shaped otherwise, or a refused key answered with a 200:
  // the dry run shows the first page as it came, with the key cut out.
  let firstAnswer: unknown = undefined;
  for (let page = 1; page <= MAX_PAGES; page++) {
    // The key is in the path: log the status, never the URL.
    const res = await fetch(`${DCM_API}/get-active-coupons/${encodeURIComponent(key)}?page=${page}&pageSize=${DCM_PAGE_SIZE}`, {
      headers: { accept: "application/json" },
      signal: AbortSignal.timeout(20_000),
    });
    if (!res.ok) {
      console.error("dcm coupons http", res.status, (await res.text()).slice(0, 300));
      couponsError = `http_${res.status}_page_${page}`;
      break;
    }
    const text = await res.text();
    let body: unknown;
    try {
      body = JSON.parse(text);
    } catch {
      body = text;
    }
    if (firstAnswer === undefined) firstAnswer = body;
    const results = couponsOf(body);
    coupons.push(...results);
    if (results.length < DCM_PAGE_SIZE) break;
  }

  const sb = createClient(SUPABASE_URL, SERVICE_ROLE);
  const now = Date.now();
  const skipped: Record<string, number> = {};
  const rejected: Record<string, number> = {};
  let put = 0;
  let mapped = 0;
  for (const c of coupons) {
    const m = mapCoupon(c, now);
    if (!m.ok) {
      skipped[m.reason] = (skipped[m.reason] ?? 0) + 1;
      continue;
    }
    mapped++;
    if (dry) continue;
    const { data, error } = await sb.rpc("zad_deal_put", { p: m.payload });
    if (error || !data?.ok) {
      const reason = error ? "rpc_error" : String(data?.reason ?? "unknown");
      rejected[reason] = (rejected[reason] ?? 0) + 1;
      if (error) console.error("zad_deal_put failed:", error.message);
      continue;
    }
    put++;
  }

  const syncedAt = new Date(now).toISOString();
  const couponRowList = couponsError ? [] : coupons.flatMap((c) => couponRows(c, now, syncedAt) ?? []);
  const mainKey = (Deno.env.get("DCM_MAIN_API_KEY") ?? "").trim();
  const networkId = (Deno.env.get("DCM_NETWORK_ID") ?? "dcm").trim() || "dcm";
  const offers: OffersPass | null = mainKey ? await offersPass(sb, networkId, mainKey, syncedAt) : null;
  if (offers && !offers.ok) console.error("dcm offers:", offers.error);

  // Upsert, then retire what this run did not see — per source, and only when that source answered.
  const writes: Array<["dcm_coupon" | "dcm_offer", CouponRow[]]> = [];
  if (!couponsError) writes.push(["dcm_coupon", couponRowList]);
  if (offers?.ok) writes.push(["dcm_offer", offers.rows]);
  let couponRowsWritten = 0;
  let writeError: string | null = null;
  if (!dry) {
    for (const [source, rows] of writes) {
      for (let i = 0; i < rows.length; i += 200) {
        const { error } = await sb.from("zad_coupons")
          .upsert(rows.slice(i, i + 200), { onConflict: "source,external_id,country_code" });
        if (error) {
          writeError = error.message;
          break;
        }
        couponRowsWritten += Math.min(200, rows.length - i);
      }
      if (writeError) break;
      const { error } = await sb.from("zad_coupons").update({ active: false })
        .eq("source", source).lt("synced_at", syncedAt);
      if (error) writeError = error.message;
    }
    if (writeError) console.error("zad_coupons write failed:", writeError);
  }

  const offersSummary = offers === null
    ? { skipped: "no_main_api_key" }
    : offers.ok
    ? {
      offers: offers.offers, rows: offers.rows.length, linked: offers.linked, needs_terms: offers.needsTerms,
      trending: offers.rows.filter((r) => r.is_trending).length,
    }
    : { error: offers.error };
  console.log(`dcm: ${coupons.length} coupons, ${mapped} mapped, ${put} put, ${couponRowsWritten} coupon rows${dry ? " (dry)" : ""}`,
    skipped, rejected, offersSummary);
  const failed = (couponsError && !offers?.ok) || writeError;
  return json({
    coupons: coupons.length, mapped, put, dry, skipped, rejected,
    coupon_rows: dry ? couponRowList.length + (offers?.ok ? offers.rows.length : 0) : couponRowsWritten,
    offers: offersSummary,
    ...(couponsError ? { coupons_error: couponsError } : {}),
    ...(writeError ? { write_error: writeError } : {}),
    ...(dry && coupons[0] ? { first_keys: Object.keys(coupons[0]) } : {}),
    ...(dry ? { answer: describeAnswer(firstAnswer, key) } : {}),
  }, failed ? 502 : 200);
});
