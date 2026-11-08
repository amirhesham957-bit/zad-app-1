// deno-lint-ignore-file
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.6";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "apikey, x-client-info, Content-Type, Authorization",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace(/^Bearer\s+/i, "");
    if (!token) {
      return new Response(JSON.stringify({ error: "missing_auth" }), { status: 401, headers: corsHeaders });
    }

    // Never trust a user_id from the request body — resolve the caller's own
    // id from their verified JWT so this can only ever delete the caller's
    // own account (never someone else's, even if body were tampered with).
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const { data: userRes, error: userErr } = await callerClient.auth.getUser();
    if (userErr || !userRes?.user) {
      return new Response(JSON.stringify({ error: "invalid_session" }), { status: 401, headers: corsHeaders });
    }

    // المسح الفعلي بعد ١٤ يوم (zad_purge_due_accounts). هنا الطلب بس، باسم صاحب الجلسة.
    const { data: purgeAt, error } = await callerClient.rpc("zad_request_account_deletion");
    if (error) {
      console.error(`[DeleteAccount] request failed: ${error.message}`);
      return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: corsHeaders });
    }

    return new Response(JSON.stringify({ success: true, purge_at: purgeAt }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (e) {
    console.error(`[DeleteAccount] Error: ${(e as Error).message}`);
    return new Response(JSON.stringify({ error: (e as Error).message }), { status: 500, headers: corsHeaders });
  }
});
