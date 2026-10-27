// تجربة الأسبوعين (ZAD_PLAN ٥.٤) في إشعار التطبيق: data-only عشان التطبيق هو اللي يعرضه بزرارين المرحلة —
// إشعار بـnotification block أندرويد بيعرضه لوحده والتطبيق في الخلفية، من غير أزرار. السطور من الجدول زي تليجرام.
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { type HabitTrial, habitTrialStage, habitTrialText } from "../_shared/habitTrial.ts";

export const HABIT_TRIAL_KINDS = new Set(["habit_trial", "habit_trial_result"]);

/** نص الإشعار وبياناته، أو null لو التجربة مابقتش مستنية رد (والإشعار بيتبعت عادي). */
export function habitTrialPush(
  trial: HabitTrial,
  modelText: string,
): { body: string; data: Record<string, string> } | null {
  const stage = habitTrialStage(trial);
  const lines = habitTrialText(trial);
  if (!stage || !lines) return null;
  return {
    body: `${modelText.slice(0, 180)}\n\n${lines}`,
    data: { kind: "habit_trial", trial_id: trial.id, stage, route: "home" },
  };
}

/** التجربة اللي المهمة [taskId] اقترحتها أو قاست نتيجتها، ولسه مستنية رد. أي فشل = null. */
export async function habitTrialForTask(sb: SupabaseClient, userId: string, taskId: string): Promise<HabitTrial | null> {
  const { data, error } = await sb.from("zad_habit_trials")
    .select("id,kind,category,currency,status,baseline_weekly,result_weekly")
    .eq("user_id", userId)
    .or(`and(proposal_task_id.eq.${taskId},status.eq.proposed),and(result_task_id.eq.${taskId},status.eq.measured)`)
    .maybeSingle();
  if (error) console.error("[habit_trial] lookup failed:", error.message);
  return (data as HabitTrial | null) ?? null;
}
