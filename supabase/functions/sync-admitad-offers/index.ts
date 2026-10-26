// sync-admitad-offers — Admitad's coupons for our website ⇐ zad_deal_put (source_kind 'partner', ZAD_PLAN 4.5).
//
// Secrets: ADMITAD_WEBSITE_ID (the ad space id), and either ADMITAD_API_TOKEN (a token minted by hand —
// Admitad's expire, so it stops working on its own) or ADMITAD_CLIENT_ID + ADMITAD_CLIENT_SECRET, from which
// every run mints its own through the client_credentials grant. The cron header is X-Admitad-Cron-Secret
// against ADMITAD_SYNC_CRON_SECRET. ?dry=1 maps and counts without writing — the first run should be one.
//
// No cron calls this yet: scheduling it before the secrets exist would only log a 500 a day.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { secretMatches } from "../_shared/cronSecret.ts";
import { ADMITAD_API, type AdmitadCoupon, basicHeader, mapCoupon } from "./admitad.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const PAGE = 500;
const MAX_PAGES = 10;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

async function accessToken(): Promise<string | null> {
  const fixed = (Deno.env.get("ADMITAD_API_TOKEN") ?? "").trim();
  if (fixed) return fixed;
  const id = (Deno.env.get("ADMITAD_CLIENT_ID") ?? "").trim();
  const secret = (Deno.env.get("ADMITAD_CLIENT_SECRET") ?? "").trim();
  if (!id || !secret) return null;
  const res = await fetch(`${ADMITAD_API}/token/`, {
    method: "POST",
    headers: { authorization: basicHeader(id, secret), "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "client_credentials", client_id: id, scope: "coupons_for_website" }),
    signal: AbortSignal.timeout(20_000),
  });
  if (!res.ok) {
    console.error("admitad token http", res.status, (await res.text()).slice(0, 300));
    return null;
  }
  return ((await res.json()) as { access_token?: string }).access_token ?? null;
}

Deno.serve(async (req) => {
  if (!(await secretMatches(req.headers.get("X-Admitad-Cron-Secret"), "ADMITAD_SYNC_CRON_SECRET"))) {
    return json({ error: "unauthorized" }, 401);
  }
  const dry = new URL(req.url).searchParams.get("dry") === "1";
  const website = (Deno.env.get("ADMITAD_WEBSITE_ID") ?? "").trim();
  if (!/^\d+$/.test(website)) return json({ error: "no_website_id" }, 500);
  const token = await accessToken();
  if (!token) return json({ error: "no_token" }, 500);

  const coupons: AdmitadCoupon[] = [];
  for (let page = 0; page < MAX_PAGES; page++) {
    const url = `${ADMITAD_API}/coupons/website/${website}/?limit=${PAGE}&offset=${page * PAGE}`;
    const res = await fetch(url, { headers: { authorization: `Bearer ${token}` }, signal: AbortSignal.timeout(20_000) });
    if (!res.ok) {
      console.error("admitad coupons http", res.status, (await res.text()).slice(0, 300));
      return json({ error: "coupons_failed", status: res.status }, 502);
    }
    const body = (await res.json()) as { results?: AdmitadCoupon[]; _meta?: { count?: number } };
    const results = body.results ?? [];
    coupons.push(...results);
    if (results.length < PAGE || coupons.length >= (body._meta?.count ?? 0)) break;
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

  console.log(`admitad: ${coupons.length} coupons, ${mapped} mapped, ${put} put${dry ? " (dry)" : ""}`, skipped, rejected);
  return json({ coupons: coupons.length, mapped, put, dry, skipped, rejected });
});
