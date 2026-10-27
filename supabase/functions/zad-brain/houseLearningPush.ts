// «اتعلمت إن» (ZAD_PLAN ٥.٢) في إشعار التطبيق: data-only عشان التطبيق هو اللي يعرضه بزرارين «صح / مش صح» — زي
// تجربة الأسبوعين (habitTrialPush.ts). الملاحظة من الجدول تحت كلام الموديل، عشان الزرار يبقى على جملة باينة.
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

export const HOUSE_LEARNING_KIND = "home_weekly_digest";

export interface PendingLearning {
  id: string;
  note: string;
}

/** نص الإشعار وبياناته. */
export function houseLearningPush(learning: PendingLearning, modelText: string): { body: string; data: Record<string, string> } {
  return {
    body: `${modelText.slice(0, 180)}\n\n🧠 ${learning.note}`,
    data: { kind: "house_learning", learning_id: learning.id, route: "home" },
  };
}

/** الملاحظة اللي الملخص [taskId] قالها ولسه مااتجاوبش. أي فشل = null (والإشعار بيتبعت عادي). */
export async function houseLearningForTask(sb: SupabaseClient, userId: string, taskId: string): Promise<PendingLearning | null> {
  const { data, error } = await sb.from("zad_house_learnings")
    .select("id,note").eq("user_id", userId).eq("task_id", taskId).is("answer", null).maybeSingle();
  if (error) console.error("[house_learning] lookup failed:", error.message);
  return (data as PendingLearning | null) ?? null;
}
