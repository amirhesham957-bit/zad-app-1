// م٧.٨: تنفيذ تعديل الهدف الواقف **بعد موافقة العميل الصريحة فقط**، خلف ZAD_MEMBER_GOALS (مقفول ⇒ الأداة مش في القايمة).
// الموديل مابيحددش الميعاد: السيرفر بيحسبه من التقدم الفعلي (zad_events / المهام المنجزة) ويسجله **عرض** (zad_goal_offers)
// وقت ما الاقتراح يتعرض في اللقطة. التنفيذ بيحتاج: موافقة صريحة + goal_id مطابق لعرض سيرفر لسه مفتوح (٢٤ ساعة، مااتستهلكش،
// واتعرض في لفة قبل لفة الموافقة). «أيوه» لوحدها مش كفاية. الكتابة الوحيدة = goal.set من الباب، والرقم المستهدف ثابت.
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
    "نفّذ مدّ ميعاد هدف واقف (life_goals[].proposal) **بعد ما العميل يوافق صراحة** على عرض محدد اتعرض عليه في رد سابق " +
    "بالاسم والميعاد الجديد. «أيوه» لوحدها من غير عرض مرفوضة. اعرض الاسم والميعاد واستنى رده؛ ماتنادّيهاش في نفس الرد اللي عرضت فيه. " +
    "goal_id لازم يطابق goal_id اللي في الاقتراح بالظبط، وإلا مرفوض. السيرفر هو اللي بيحدد الميعاد، والرقم المستهدف مابيتغيّرش.",
  input_schema: {
    type: "object",
    properties: {
      goal_id: { type: "string", description: "goal_id بتاع الهدف من life_goals[].id (إلزامي، لازم يطابق العرض)" },
      deadline_date: { type: "string", description: "اختياري: الميعاد الجديد YYYY-MM-DD اللي اتعرض. لو مختلف عن عرض السيرفر = مرفوض." },
    },
    required: ["goal_id"],
  },
};

export const GOAL_ADJUST_FLAG_OFF = "مرفوض: تعديل الأهداف التلقائي مش متاح دلوقتي.";
export const GOAL_ADJUST_NEEDS_APPROVAL =
  "مرفوض: العميل ماوافقش لسه. اعرض عليه التعديل كسؤال (اسم الهدف والميعاد الجديد) واستنى «أيوه» في رسالته الجاية.";
export const GOAL_ADJUST_NEEDS_GOAL_ID = "مرفوض: لازم goal_id بتاع الهدف من life_goals (نفس اللي في الاقتراح).";
export const GOAL_ADJUST_NO_OFFER =
  "مرفوض: مفيش عرض مفتوح للهدف ده. «أيوه» لوحدها مش كفاية؛ لازم عرض بالاسم والميعاد الجديد (من life_goals) والعميل يوافق عليه في رسالته الجاية.";
export const GOAL_ADJUST_OFFER_SAME_TURN =
  "مرفوض: العرض ده لسه جديد في اللفة دي. اعرضه على العميل بالاسم والميعاد واستنى موافقته في رسالته الجاية.";
export const GOAL_ADJUST_OFFER_EXPIRED = "مرفوض: العرض انتهى (أكتر من ٢٤ ساعة). اعرضه من جديد.";
export const GOAL_ADJUST_OFFER_USED = "مرفوض: العرض ده اتنفّذ قبل كده.";
export const GOAL_ADJUST_CHILD = "مرفوض: التعديل التلقائي مش متاح لأهداف الأطفال.";
export const GOAL_ADJUST_DEADLINE_MISMATCH = "مرفوض: الميعاد اللي ذكرته مختلف عن اللي اتعرض. اعرض الميعاد الصح على العميل.";

/**
 * عروض اللفة الحالية اللي اتسجلت **أول مرة** في اللقطة اللي اتبنت للفة دي (is_new): العميل ماشافهاش قبل كده، فمينفعش
 * تتنفّذ في نفس اللفة. بتتكتب فوق مع كل بناء لقطة لنفس العميل، فاللفة الجاية (عرض مش جديد) بتعدّي.
 */
const freshOffers = new Map<string, Set<string>>();
export const isFreshGoalOffer = (userId: string, goalId: string): boolean => freshOffers.get(userId)?.has(goalId) ?? false;

export interface GoalOfferInput { goalId: string; deadline: string }
/** يسجل العروض من السيرفر ويرجّع الأهداف اللي عرضها اتسجّل (الباقي = من غير اقتراح). أي فشل = من غير اقتراح. */
export async function recordGoalOffers(sb: SupabaseClient, userId: string, offers: readonly GoalOfferInput[]): Promise<Set<string>> {
  const ok = new Set<string>();
  const fresh = new Set<string>();
  for (const o of offers) {
    try {
      const { data, error } = await sb.rpc("zad_goal_offer_record", { p_user: userId, p_goal: o.goalId, p_deadline: o.deadline });
      const r = data as { ok?: boolean; is_new?: boolean } | null;
      if (!error && r?.ok) { ok.add(o.goalId); if (r.is_new) fresh.add(o.goalId); }
    } catch { /* من غير اقتراح */ }
  }
  freshOffers.set(userId, fresh);
  return ok;
}

export interface GoalAdjustmentPlan { ok: true; deadline: string; weeks: number; step: number }
export type GoalAdjustmentResult = GoalAdjustmentPlan | { ok: false; reason: string };

/** قراية + حساب بس (مفيش كتابة). عميل واحد، هدف نشط بالـid، ومقيّد بـuser_id. */
export async function planGoalAdjustment(
  sb: SupabaseClient, userId: string, goalId: string, now: Date = new Date(),
): Promise<GoalAdjustmentResult & { goal?: Record<string, unknown> }> {
  const { data: goal } = await sb.from("agent_goals")
    .select("id,title,metric,target_value,deadline_date,created_at,progress_kind")
    .eq("user_id", userId).eq("id", goalId).eq("status", "active").maybeSingle();
  if (!goal) return { ok: false, reason: "مفيش هدف نشط بالـgoal_id ده." };
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
