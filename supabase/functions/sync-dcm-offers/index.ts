// sync-dcm-offers — DCMnetwork's Codes Hub coupons for our account ⇐ zad_deal_put (source_kind 'partner', ZAD_PLAN 4.5).
//
// Secrets: DCM_API_KEY (the "Data API Key" under Account > User Details & API Key on partner.dcmnetwork.com,
// already set on the project), and DCM_SYNC_CRON_SECRET against the X-Dcm-Cron-Secret header. ?dry=1 maps
// and counts without writing, and returns the first coupon's keys so the field names get checked against a
// real answer — the first run should be one.
//
// Only the official API DCM's support sent (dcm.ts). The portal-session route stays frozen (owner's
// decision, 2026-10-26). No cron calls this yet: one dry run first.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { secretMatches } from "../_shared/cronSecret.ts";
import { couponsOf, DCM_API, DCM_PAGE_SIZE, type DcmCoupon, describeAnswer, mapCoupon } from "./dcm.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const MAX_PAGES = 20;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

Deno.serve(async (req) => {
  if (!(await secretMatches(req.headers.get("X-Dcm-Cron-Secret"), "DCM_SYNC_CRON_SECRET"))) {
    return json({ error: "unauthorized" }, 401);
  }
  const dry = new URL(req.url).searchParams.get("dry") === "1";
  const key = (Deno.env.get("DCM_API_KEY") ?? "").trim();
  if (!key) return json({ error: "no_api_key" }, 500);

  const coupons: DcmCoupon[] = [];
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
      return json({ error: "coupons_failed", status: res.status, page }, 502);
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

  console.log(`dcm: ${coupons.length} coupons, ${mapped} mapped, ${put} put${dry ? " (dry)" : ""}`, skipped, rejected);
  return json({
    coupons: coupons.length, mapped, put, dry, skipped, rejected,
    ...(dry && coupons[0] ? { first_keys: Object.keys(coupons[0]) } : {}),
    ...(dry ? { answer: describeAnswer(firstAnswer, key) } : {}),
  });
});
