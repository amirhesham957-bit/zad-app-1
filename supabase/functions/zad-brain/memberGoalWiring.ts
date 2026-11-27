// م٧.٨: توصيل memberGoal بـagent_goals، والتقدم الأسبوعي من zad_events (kind = goal.progress، payload.row_id = id الهدف).
// قراية بس. التعديل بيتعرض **اقتراح** والعقل مايكتبش غير بعد موافقة الفرد، وبنية goal.set من الباب (zad_commit_intent).
// أهداف المبلغ بس (progress_kind = amount)؛ هدف العدّ تقدمه من مهام مش أحداث. خلف ZAD_MEMBER_GOALS (مقفول افتراضياً).

import { adjustStalledGoal, type GoalAdjustment, goalStatus, type GoalStatus } from "../_shared/or/memberGoal.ts";

export const MEMBER_GOALS_FLAG = "ZAD_MEMBER_GOALS";
const WEEK_MS = 7 * 86_400_000;

export function memberGoalsEnabled(get: (k: string) => string | undefined): boolean {
  const v = (get(MEMBER_GOALS_FLAG) ?? "").trim().toLowerCase();
  return v === "1" || v === "true" || v === "on";
}

export interface GoalEventRow { occurred_at: string; payload: { row_id?: unknown; amount?: unknown } | null }
export interface GoalRow {
  id: string; title: string; target_value: number | string | null; deadline_date: string | null;
  created_at: string | null; progress_kind?: string | null;
}

/** المحقق في كل أسبوع **منقضي بالكامل** من تاريخ إنشاء الهدف (مش تراكمي). الأسبوع الجاري مش محسوب. */
export function weeklyProgress(goalId: string, createdAtIso: string, events: readonly GoalEventRow[], now: Date): number[] {
  const start = Date.parse(createdAtIso);
  if (!Number.isFinite(start)) return [];
  const full = Math.max(0, Math.floor((now.getTime() - start) / WEEK_MS));
  const out = new Array<number>(full).fill(0);
  for (const e of events) {
    if (String(e.payload?.row_id ?? "") !== goalId) continue;
    const amt = Number(e.payload?.amount);
    const t = Date.parse(e.occurred_at);
    if (!Number.isFinite(amt) || !Number.isFinite(t) || t < start) continue;
    const w = Math.floor((t - start) / WEEK_MS);
    if (w < full) out[w] += amt;
  }
  return out;
}

export interface MemberGoalView {
  status: GoalStatus;
  adjustment: GoalAdjustment;
  /** نص اقتراح للعقل يعرضه على الفرد؛ null لو ماشي/اتحقق. */
  proposal: string | null;
  /** الميعاد الجديد اللي السيرفر هيسجله عرض (zad_goal_offers)؛ null لو مفيش اقتراح. */
  offerDeadline: string | null;
}

/** أهداف العدّ (progress_kind = tasks): كل مهمة منجزة مرتبطة بالهدف = ١ في أسبوع إنجازها (agent_tasks.updated_at وهي done). */
export interface GoalTaskRow { goal_id: string; updated_at: string }
export function taskEventsFor(goalId: string, tasks: readonly GoalTaskRow[]): GoalEventRow[] {
  return tasks.filter((t) => t.goal_id === goalId).map((t) => ({ occurred_at: t.updated_at, payload: { row_id: goalId, amount: 1 } }));
}

/** أهداف المبلغ بتقرا goal.progress من zad_events، وأهداف العدّ من المهام المنجزة (taskEvents). غير كده null. */
export function memberGoalView(
  goal: GoalRow, events: readonly GoalEventRow[], now: Date = new Date(), taskEvents: readonly GoalEventRow[] | null = null,
): MemberGoalView | null {
  const isCount = goal.progress_kind === "tasks";
  if ((goal.progress_kind !== "amount" && !(isCount && taskEvents)) || !goal.created_at || !goal.deadline_date) return null;
  if (isCount) events = taskEvents!;
  const target = Number(goal.target_value);
  const created = Date.parse(goal.created_at);
  const end = Date.parse(`${goal.deadline_date}T23:59:59Z`);
  if (!(target > 0) || !Number.isFinite(created) || !Number.isFinite(end) || end <= created) return null;
  const weeks = Math.max(1, Math.ceil((end - created) / WEEK_MS));
  const input = { target, weeks, weeklyProgress: weeklyProgress(goal.id, goal.created_at, events, now) };
  const status = goalStatus(input);
  const adjustment = adjustStalledGoal(input);
  const offerDeadline = adjustment.kind === "extend_deadline" ? extendedDeadline(goal.created_at, adjustment.weeks) : null;
  const proposal = adjustment.kind === "extend_deadline" && offerDeadline
    ? `الهدف «${goal.title}» (goal_id=${goal.id}) واقف (أسبوعين تحت نص الحصة). اقتراح محدد: مدّ ميعاده لـ${offerDeadline}، فالخطوة الأسبوعية تبقى ${Math.ceil(adjustment.stepPerWeek)}. الرقم المستهدف ثابت. اعرضه على العميل كسؤال بالاسم والميعاد ده بالظبط واستنى رده في رسالته الجاية (مش في نفس الرد). لو وافق صراحة على العرض ده نادِ apply_goal_adjustment بـgoal_id ده بالظبط؛ السيرفر بيرفض لو العرض مش مسجّل عنده أو انتهى أو اتنفّذ. «أيوه» من غير عرض مش موافقة.`
    : null;
  return { status, adjustment, proposal, offerDeadline: proposal ? offerDeadline : null };
}

/** الميعاد الجديد (YYYY-MM-DD) = تاريخ إنشاء الهدف + عدد الأسابيع الجديد من adjustStalledGoal. السيرفر بيحسبه، مش الموديل. */
export function extendedDeadline(createdAtIso: string, weeks: number): string | null {
  const c = Date.parse(createdAtIso);
  if (!Number.isFinite(c) || !(weeks > 0)) return null;
  return new Date(c + weeks * WEEK_MS).toISOString().slice(0, 10);
}

const AFFIRM = new Set(["ايوه", "ايوة", "أيوه", "أيوة", "اه", "آه", "اة", "موافق", "موافقة", "تمام", "ماشي", "نفذ", "نفّذ", "اعمل", "يلا", "اكيد", "أكيد", "yes", "ok", "okay", "sure"]);
const NEGATE = new Set(["لا", "لأ", "لاا", "مش", "ماتعدل", "متعدل", "بلاش", "استنى", "لسه", "no", "not", "dont", "don't"]);

/** موافقة صريحة في رسالة العميل في اللفة دي: كلمة موافقة وكلمة نفي مفيش، ورسالة قصيرة (≤ ٨ كلمات). */
export function isExplicitApproval(said: string | undefined): boolean {
  if (!said) return false;
  const words = said.toLowerCase().replace(/[\u064B-\u065F]/g, "").split(/[^\p{L}\p{N}']+/u).filter(Boolean);
  if (words.length === 0 || words.length > 8) return false;
  return words.some((w) => AFFIRM.has(w)) && !words.some((w) => NEGATE.has(w));
}
