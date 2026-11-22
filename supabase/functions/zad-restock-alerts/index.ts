// zad-restock-alerts — م٦.٢: كرون يومي بيبعت تنبيه «محتاجه وقريب» في مركز الإشعارات.
// الحارس: هيدر X-Restock-Alert-Cron-Secret (verify_jwt = false زي zad-fx-refresh). القرار في _shared/or/restockAlertDispatch.ts.
// مابيكتبش في جداول الباب: app_notifications وسجل التنبيهات بس، زي restock_link.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { secretMatches } from "../_shared/cronSecret.ts";
import { type Candidate, planRestockAlert } from "../_shared/or/restockAlertDispatch.ts";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

Deno.serve(async (req) => {
  if (!(await secretMatches(req.headers.get("X-Restock-Alert-Cron-Secret"), "ZAD_RESTOCK_ALERT_CRON_SECRET"))) {
    return json({ error: "unauthorized" }, 401);
  }
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data, error } = await sb.rpc("zad_restock_alert_candidates", { p_limit: 500 });
  if (error) {
    console.error("[restock-alerts] candidates:", error.message);
    return json({ error: "candidates_failed" }, 500);
  }
  const stats: Record<string, number> = { sent: 0 };
  const now = Date.now();
  for (const c of (data ?? []) as Candidate[]) {
    try {
      const plan = await planRestockAlert(sb, c, now);
      if (!plan.send) {
        stats[plan.reason] = (stats[plan.reason] ?? 0) + 1;
        continue;
      }
      const note = await sb.from("app_notifications").insert({ user_id: c.user_id, title: plan.title, message: plan.body, bot_push: true });
      if (note.error) throw new Error(note.error.message);
      const log = await sb.from("zad_restock_alert_log").insert(plan.itemKeys.map((item_key) => ({ user_id: c.user_id, item_key })));
      if (log.error) console.error("[restock-alerts] log:", log.error.message);
      stats.sent++;
    } catch (e) {
      stats.failed = (stats.failed ?? 0) + 1;
      console.error("[restock-alerts] household failed:", (e as Error).message);
    }
  }
  console.log("[restock-alerts]", JSON.stringify(stats));
  return json({ ok: true, ...stats });
});
