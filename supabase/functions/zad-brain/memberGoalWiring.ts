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
}

export function memberGoalView(goal: GoalRow, events: readonly GoalEventRow[], now: Date = new Date()): MemberGoalView | null {
  if (goal.progress_kind !== "amount" || !goal.created_at || !goal.deadline_date) return null;
  const target = Number(goal.target_value);
  const created = Date.parse(goal.created_at);
  const end = Date.parse(`${goal.deadline_date}T23:59:59Z`);
  if (!(target > 0) || !Number.isFinite(created) || !Number.isFinite(end) || end <= created) return null;
  const weeks = Math.max(1, Math.ceil((end - created) / WEEK_MS));
  const input = { target, weeks, weeklyProgress: weeklyProgress(goal.id, goal.created_at, events, now) };
  const status = goalStatus(input);
  const adjustment = adjustStalledGoal(input);
  const proposal = adjustment.kind === "extend_deadline"
    ? `الهدف واقف (أسبوعين تحت نص الحصة). اقتراح: مدّ الميعاد لـ${adjustment.weeks} أسبوع من أول الهدف، فالخطوة الأسبوعية تبقى ${Math.ceil(adjustment.stepPerWeek)}. الرقم المستهدف ثابت. اعرضه على العميل كسؤال، ولو وافق نفّذه بـset_life_goal بميعاد جديد (deadline_date)؛ ماتنفّذش من غير موافقته.`
    : null;
  return { status, adjustment, proposal };
}
