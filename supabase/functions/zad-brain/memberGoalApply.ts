// م٧.٨: تنفيذ تعديل الهدف الواقف **بعد موافقة العميل الصريحة فقط**، خلف ZAD_MEMBER_GOALS (مقفول ⇒ الأداة مش في القايمة).
// الموديل مابيحددش الميعاد: السيرفر بيعيد حساب الوقف من التقدم الفعلي (zad_events / المهام المنجزة) ويطلع الميعاد
// الجديد من adjustStalledGoal. الكتابة الوحيدة = goal.set من الباب (zad_commit_intent)، والرقم المستهدف ثابت.
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import type { ToolDef } from "./callModel.ts";
import {
  extendedDeadline, type GoalEventRow, isExplicitApproval, memberGoalsEnabled, memberGoalView, taskEventsFor,
} from "./memberGoalWiring.ts";

export const APPLY_GOAL_ADJUSTMENT = "apply_goal_adjustment";
export const memberGoalsOn = (): boolean => memberGoalsEnabled((k) => Deno.env.get(k));

export const APPLY_GOAL_ADJUSTMENT_TOOL: ToolDef = {
  name: APPLY_GOAL_ADJUSTMENT,
  description:
    "نفّذ مدّ ميعاد هدف واقف (life_goals[].proposal) **بعد ما العميل يوافق صراحة** («أيوه»، «موافق») على سؤالك. " +
    "اسأله الأول واستنى رده؛ ماتنادّيهاش في نفس الرد اللي سألت فيه. السيرفر بيحسب الميعاد الجديد، والرقم المستهدف مابيتغيّرش. goal_title = عنوان الهدف بالظبط.",
  input_schema: {
    type: "object",
    properties: { goal_title: { type: "string", description: "عنوان الهدف من life_goals بالظبط" } },
    required: ["goal_title"],
  },
};

export const GOAL_ADJUST_FLAG_OFF = "مرفوض: تعديل الأهداف التلقائي مش متاح دلوقتي.";
export const GOAL_ADJUST_NEEDS_APPROVAL =
  "مرفوض: العميل ماوافقش لسه. اعرض عليه التعديل كسؤال (مدّ الميعاد والخطوة الجديدة) واستنى «أيوه» في رسالته الجاية.";

export interface GoalAdjustmentPlan { ok: true; deadline: string; weeks: number; step: number }
export type GoalAdjustmentResult = GoalAdjustmentPlan | { ok: false; reason: string };

/** قراية + حساب بس (مفيش كتابة). عميل واحد، هدف نشط بنفس العنوان، ومقيّد بـuser_id. */
export async function planGoalAdjustment(
  sb: SupabaseClient, userId: string, title: string, now: Date = new Date(),
): Promise<GoalAdjustmentResult & { goal?: Record<string, unknown> }> {
  const { data: goal } = await sb.from("agent_goals")
    .select("id,title,metric,target_value,deadline_date,created_at,progress_kind")
    .eq("user_id", userId).eq("title", title).eq("status", "active").maybeSingle();
  if (!goal) return { ok: false, reason: `مفيش هدف نشط اسمه «${title}».` };
  const g = goal as { id: string; progress_kind: string | null; created_at: string | null };
  let events: GoalEventRow[] = [];
  let taskEvents: GoalEventRow[] | null = null;
  if (g.progress_kind === "tasks") {
    const { data } = await sb.from("agent_tasks").select("goal_id,updated_at")
      .eq("user_id", userId).eq("goal_id", g.id).eq("status", "done").limit(2000);
    taskEvents = taskEventsFor(g.id, (data ?? []) as Array<{ goal_id: string; updated_at: string }>);
  } else {
    const { data } = await sb.from("zad_events").select("occurred_at,payload")
      .eq("user_id", userId).eq("kind", "goal.progress").limit(2000);
    events = (data ?? []) as GoalEventRow[];
  }
  const view = memberGoalView(goal as never, events, now, taskEvents);
  if (!view || view.adjustment.kind !== "extend_deadline") return { ok: false, reason: "الهدف مش واقف، مفيش حاجة تتعدّل." };
  const deadline = extendedDeadline(g.created_at ?? "", view.adjustment.weeks);
  if (!deadline) return { ok: false, reason: "مش قادر أحسب الميعاد الجديد." };
  return { ok: true, deadline, weeks: view.adjustment.weeks, step: Math.ceil(view.adjustment.stepPerWeek), goal: goal as Record<string, unknown> };
}

export { isExplicitApproval };
