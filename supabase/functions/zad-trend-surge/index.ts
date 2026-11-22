// zad-trend-surge (م٦.٣) — كرون يومي: بيقرا إشارات الترند المجمّعة ويسجّل القفزات (z≥٣، ≥٥ بيوت).
// مجمّع بس، مفيش user_id. الهايب لوحده مش سبب ترشيح (recommendBuy دايماً false).
import { createClient } from "jsr:@supabase/supabase-js@2";
import { secretMatches } from "../_shared/cronSecret.ts";
import { recordSurges } from "../_shared/or/trendSurgeRecord.ts";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

Deno.serve(async (req) => {
  if (!(await secretMatches(req.headers.get("X-Trend-Cron-Secret"), "ZAD_TREND_CRON_SECRET"))) {
    return json({ error: "unauthorized" }, 401);
  }
  try {
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const recorded = await recordSurges(sb);
    return json({ ok: true, recorded });
  } catch (e) {
    console.error("[zad-trend-surge]", e instanceof Error ? e.message : e);
    return json({ ok: false, error: "failed" }, 500);
  }
});
