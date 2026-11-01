// get-user-deals — the DCMnetwork offers and codes for the signed-in customer's country (ZAD_PLAN 4.5).
//
// GET, with the customer's JWT (verify_jwt = true). The customer is the token's, never a user_id from the
// request: another account's country is not ours to read. ?country=XX overrides the country (the deals of a
// country are not private). Answers {country, fallback, trending_deals, available_coupons} — see deals.ts.
// Rows come from zad_coupons, filled by sync-dcm-offers; only rows with our tracked link are ever returned.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { type DealRow, resolveCountry, shapeDeals } from "./deals.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const COLUMNS = "source,external_id,country_code,store,title,code,category,click_url,logo_url,payout_percent,is_trending,valid_until";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

Deno.serve(async (req) => {
  if (req.method !== "GET" && req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const sb = createClient(SUPABASE_URL, SERVICE_ROLE);
  const { data: caller } = token ? await sb.auth.getUser(token) : { data: { user: null } };
  const userId = caller?.user?.id;
  if (!userId) return json({ error: "unauthorized" }, 401);

  const { data: user } = await sb.from("zad_users").select("country,travel_country").eq("id", userId).maybeSingle();
  const country = resolveCountry(new URL(req.url).searchParams.get("country"), user);

  const { data, error } = await sb.from("zad_coupons").select(COLUMNS)
    .eq("active", true)
    .not("click_url", "is", null)
    .in("country_code", country ? [country, "GLOBAL"] : ["GLOBAL"])
    .or(`valid_until.is.null,valid_until.gt.${new Date().toISOString()}`)
    .limit(500);
  if (error) {
    console.error("get-user-deals read failed:", error.message);
    return json({ error: "read_failed" }, 500);
  }
  return json(shapeDeals((data ?? []) as DealRow[], country));
});
