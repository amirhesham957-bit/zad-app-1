// shein-link-converter — عروض SHEIN للخليج (SA، AE) ⇐ zad_affiliate_offers.
//
// مش «محوّل» بيركّب رابط: SHEIN بتحط النسبة جوه رابط لوحتها (شوف shein.ts). الدالة بتاخد رابط اللوحة،
// بتفتحه، وبتتأكد إن صفحته شايلة `koc_id` = SHEIN_AFFILIATE_ID قبل ما العرض يتحفظ. رابط مش بتاعنا
// أو رابط منتج عادي بيترفض بسببه، فمفيش عرض بيتنشر وهو مابيكسبش.
//
// الأكشنز (POST JSON):
//   {"action":"check","url":"https://onelink.shein.com/…"}  ⇐ {ok, koc_id, ours}
//   {"action":"save","offer":{title,url,image_url?,raw_url?,coupon_code?,target_countries?,category?}}
//
// النداء بمفتاح service role بس (`Authorization: Bearer …`): العروض بتتنشر لكل عملاء الخليج، فمفيش
// مستخدم عادي يضيف واحد. الأسرار: SHEIN_AFFILIATE_ID (لازم؛ من غيره الحفظ مقفول).
// SHEIN_REFERRAL_CODE متخزن للمالك ومابيظهرش للعميل: مش كود خصم.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { secretMatches } from "../_shared/cronSecret.ts";
import { dashboardLink, isSheinHost, kocIdIn, type OfferInput, offerRow } from "./shein.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const MAX_HOPS = 3;
const MAX_BYTES = 256_000;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

/** صفحة الرابط، ماشيين ورا التحويلات على هوستات SHEIN بس. */
async function landingPage(url: string): Promise<string | null> {
  let next = url;
  for (let hop = 0; hop <= MAX_HOPS; hop++) {
    const res = await fetch(next, {
      redirect: "manual",
      headers: { "user-agent": "Mozilla/5.0 (Linux; Android 14) Zad" },
      signal: AbortSignal.timeout(10_000),
    });
    if (res.status >= 300 && res.status < 400) {
      await res.body?.cancel();
      const to = res.headers.get("location");
      if (!to) return null;
      const target = new URL(to, next);
      if (target.protocol !== "https:" || !isSheinHost(target.hostname)) return null;
      next = target.toString();
      continue;
    }
    if (!res.ok) {
      await res.body?.cancel();
      return null;
    }
    const text = await res.text();
    return text.slice(0, MAX_BYTES);
  }
  return null;
}

async function check(url: string) {
  const link = dashboardLink(url);
  if (!link.ok) return { ok: false as const, reason: link.reason };
  const page = await landingPage(link.url);
  if (page == null) return { ok: false as const, reason: "unreachable" };
  const koc = kocIdIn(page);
  const ours = (Deno.env.get("SHEIN_AFFILIATE_ID") ?? "").trim();
  return { ok: true as const, url: link.url, koc_id: koc, ours: !!ours && koc === ours };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method" }, 405);
  const bearer = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!(await secretMatches(bearer, "SUPABASE_SERVICE_ROLE_KEY"))) return json({ error: "unauthorized" }, 401);

  let body: { action?: string; url?: string; offer?: OfferInput };
  try {
    body = await req.json();
  } catch {
    return json({ error: "bad_json" }, 400);
  }

  if (body.action === "check") {
    return json(await check(body.url ?? ""));
  }

  if (body.action === "save") {
    if (!(Deno.env.get("SHEIN_AFFILIATE_ID") ?? "").trim()) return json({ error: "no_affiliate_id" }, 500);
    const shaped = offerRow(body.offer ?? ({} as OfferInput));
    if (!shaped.ok) return json({ ok: false, reason: shaped.reason }, 422);
    const checked = await check(shaped.row.affiliate_url);
    if (!checked.ok) return json({ ok: false, reason: checked.reason }, 422);
    if (!checked.ours) {
      return json({ ok: false, reason: "not_our_affiliate_id", koc_id: checked.koc_id }, 422);
    }
    const db = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });
    const { data, error } = await db
      .from("zad_affiliate_offers")
      .upsert({ ...shaped.row, koc_id: checked.koc_id, updated_at: new Date().toISOString() }, {
        onConflict: "affiliate_url",
      })
      .select("id")
      .single();
    if (error) {
      console.error("offer save failed", error.code, error.message);
      return json({ ok: false, reason: "db" }, 500);
    }
    return json({ ok: true, id: data.id });
  }

  return json({ error: "unknown_action" }, 400);
});
