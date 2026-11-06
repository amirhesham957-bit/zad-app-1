// deno-lint-ignore-file
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.6";
import { secretMatches } from "../_shared/cronSecret.ts";
import { observedWeeks } from "./profileMath.ts";
import { favoriteStores, itemCycles, shoppingRhythm } from "./habits.ts";
import { PURCHASE_SOURCES, purchaseDaysByItem } from "../_shared/restockCycle.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseKey);

Deno.serve(async (req: Request) => {
  // verify_jwt = false والدالة شغالة بمفتاح الخدمة على كل العملاء — من غير الحارس ده أي
  // حد على النت كان يقدر يشغّلها (ويشوف user_id في `errors`). الكرون الوحيد اللي بيندهها
  // بيبعت سر العقل من الـvault (20260929220000)، نفس اللي brain-daily-analysis بيبعته.
  if (!(await secretMatches(req.headers.get("ZAD-PROACTIVE-CRON-SECRET"), "ZAD_PROACTIVE_CRON_SECRET"))) {
    return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401, headers: { "Content-Type": "application/json" } });
  }
  try {
    // Get all active users (those with transactions)
    const { data: users, error: userError } = await supabase
      .from("zad_transactions")
      .select("user_id")
      .gte("created_at", new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString())
      .limit(1000);

    if (userError) throw userError;
    const userIds = [...new Set((users || []).map(u => u.user_id).filter(Boolean))];

    console.log(`[BehaviorProfile] Processing ${userIds.length} users`);

    let successCount = 0;
    const errors: Array<{ user_id: string; message: string }> = [];

    for (const userId of userIds) {
      // Get last 90 days of transactions
      const { data: txns } = await supabase
        .from("zad_transactions")
        .select("*")
        .eq("user_id", userId)
        .gte("created_at", new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString())
        .limit(500);

      if (!txns?.length) continue;

      // Calculate avg_weekly_spending
      const totalSpent = txns.filter(t => t.is_expense).reduce((sum, t) => sum + (t.amount || 0), 0);
      // اللي اتشاف فعلاً، مش ٩٠ يوم ثابتين (profileMath.ts).
      const { data: firstTxn } = await supabase.from("zad_transactions").select("created_at")
        .eq("user_id", userId).order("created_at", { ascending: true }).limit(1).maybeSingle();
      const weeks = observedWeeks((firstTxn as { created_at?: string } | null)?.created_at);
      const avgWeeklySpending = totalSpent / weeks;

      // Calculate top_spending_categories
      const categoryTotals: Record<string, number> = {};
      txns.filter(t => t.is_expense).forEach(t => {
        const cat = t.category || "أخرى";
        categoryTotals[cat] = (categoryTotals[cat] || 0) + (t.amount || 0);
      });
      const topCategories = Object.entries(categoryTotals)
        .sort(([, a], [, b]) => b - a)
        .slice(0, 5)
        .map(([category, total]) => ({ category, total }));

      // Calculate spending_pattern_by_weekday
      const dowTotals: Record<number, { count: number; total: number }> = {};
      txns.filter(t => t.is_expense && t.created_at).forEach(t => {
        try {
          const day = new Date(t.created_at!).getDay();
          if (!dowTotals[day]) dowTotals[day] = { count: 0, total: 0 };
          dowTotals[day].count++;
          dowTotals[day].total += t.amount || 0;
        } catch { /* ignore parse errors */ }
      });
      const dayNames = ["الأحد", "الإثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت"];
      const weekdayPattern: Record<string, number> = {};
      Object.entries(dowTotals).forEach(([day, data]) => {
        weekdayPattern[dayNames[parseInt(day)]] = Math.round(data.total / Math.max(1, data.count));
      });

      // Get subscription load
      const { data: subs } = await supabase
        .from("zad_subscriptions")
        .select("amount")
        .eq("user_id", userId);
      const subMonthly = (subs || []).reduce((sum, s) => sum + (s.amount || 0), 0);

      // الشريحة ٤ (habits.ts): المحلات، ومواعيد الشرا، ودورة كل صنف — بتوقيت سوق الحساب، ومخزن البيت كله.
      const { data: me } = await supabase.from("zad_users").select("country").eq("id", userId).maybeSingle();
      const { data: tzData } = await supabase.rpc("zad_market_timezone", { p_country: (me as { country?: string } | null)?.country ?? null });
      const tz = typeof tzData === "string" && tzData ? tzData : "UTC";
      const { data: fam } = await supabase.from("family_members").select("family_id").eq("user_id", userId).maybeSingle();
      const familyId = (fam as { family_id?: string } | null)?.family_id ?? null;
      const { data: members } = familyId
        ? await supabase.from("family_members").select("user_id").eq("family_id", familyId)
        : { data: [] as Array<{ user_id: string }> };
      const homeUsers = [...new Set([userId, ...((members ?? []) as Array<{ user_id: string | null }>).map((m) => m.user_id).filter((x): x is string => !!x)])];
      const [{ data: pantry }, { data: obs }] = await Promise.all([
        supabase.from("zad_inventory").select("item_name,quantity,low_stock_threshold,category,restock_mode,restock_cycle_days,created_at")
          .or(familyId ? `user_id.eq.${userId},family_id.eq.${familyId}` : `user_id.eq.${userId}`).limit(300),
        supabase.from("zad_inventory_observations").select("item_name,observed_at")
          .in("user_id", homeUsers).in("source", [...PURCHASE_SOURCES])
          .gte("observed_at", new Date(Date.now() - 240 * 86_400_000).toISOString()).limit(2000),
      ]);
      const habitTxns = txns as Array<{ amount: number | null; merchant_name: string | null; category: string | null; created_at: string | null; is_expense: boolean | null }>;

      // Upsert profile
      const { error: upsertError } = await supabase.from("user_behavior_profile").upsert({
        favorite_stores: favoriteStores(habitTxns, tz),
        shopping_rhythm: shoppingRhythm(habitTxns, tz),
        item_cycles: itemCycles(pantry ?? [], purchaseDaysByItem(obs ?? [])),
        timezone: tz,
        user_id: userId,
        avg_weekly_spending: Math.round(avgWeeklySpending * 100) / 100,
        top_spending_categories: topCategories,
        spending_pattern_by_weekday: weekdayPattern,
        subscription_load_monthly: subMonthly,
        last_updated_at: new Date().toISOString(),
      });

      if (upsertError) {
        console.error(`[BehaviorProfile] Upsert failed for ${userId}: ${upsertError.message}`);
        errors.push({ user_id: userId, message: upsertError.message });
        continue;
      }
      successCount++;
    }

    return new Response(JSON.stringify({ users_found: userIds.length, processed: successCount, errors }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    // See the note in amazon-creators-search: `unknown` catch binding, narrowed
    // with the same helper shape the CI-gated functions use.
    const msg = String((e as { message?: string })?.message ?? e);
    console.error(`[BehaviorProfile] Error: ${msg}`);
    return new Response(JSON.stringify({ error: msg }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
