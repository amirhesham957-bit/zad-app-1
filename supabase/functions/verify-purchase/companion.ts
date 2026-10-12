// رفيق زاد's wardrobe on Google Play (2026-10-12): one-time products, checked
// with purchases.products (not purchases.subscriptions) and granted by
// zad_companion_grant_purchase (migration 20261012030000). The grant is keyed on
// Google's own orderId from the verified purchase, never on the request body,
// and an order already granted to another account is refused there.

import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
interface PlayProductPurchase {
  purchaseState?: number; // 0 = purchased, 1 = cancelled, 2 = pending
  orderId?: string;
  consumptionState?: number;
  acknowledgementState?: number;
}

/** A character, an outfit, a background or a seed pack, checked with Google
 *  (purchases.products) and granted by zad_companion_grant_purchase, keyed on
 *  Google's own orderId — so one order grants once, to one account. */
export async function verifyCompanionProduct(a: {
  packageName: string; token: string; productId: string; purchaseToken: string;
  userId: string; supabaseUrl: string;
  fetcher?: typeof fetch;
  grant?: (p: { p_user: string; p_product: string; p_order: string }) =>
    Promise<{ data: unknown; error: { message: string } | null }>;
}): Promise<Response> {
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
    `${encodeURIComponent(a.packageName)}/purchases/products/` +
    `${encodeURIComponent(a.productId)}/tokens/${encodeURIComponent(a.purchaseToken)}`;
  const res = await (a.fetcher ?? fetch)(url, { headers: { Authorization: `Bearer ${a.token}` } });
  if (!res.ok) {
    console.error("Play API rejected product token:", res.status, await res.text());
    return json({ error: "purchase_verification_failed", valid: false }, 402);
  }
  const p = (await res.json()) as PlayProductPurchase;
  if (p.purchaseState !== 0 || !p.orderId) {
    return json({ valid: false, reason: p.purchaseState === 2 ? "pending" : "not_purchased" }, 402);
  }
  const grant = a.grant ?? (async (args) => {
    const sb = createClient(a.supabaseUrl, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data, error } = await sb.rpc("zad_companion_grant_purchase", args);
    return { data, error };
  });
  const { data, error } = await grant({ p_user: a.userId, p_product: a.productId, p_order: p.orderId });
  const result = data as { ok?: boolean; reason?: string } | null;
  if (error || !result?.ok) {
    const reason = result?.reason ?? "entitlement_write_failed";
    console.error("verify-purchase: companion grant failed", { userId: a.userId, product: a.productId, reason, error: error?.message });
    return json({ valid: false, reason }, reason === "token_already_claimed" ? 409 : 500);
  }
  return json({ valid: true, kind: "companion", product: a.productId, ...result });
}
