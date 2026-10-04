// goalPace.ts — الهدف ماشي على جدوله ولا متأخر (ZAD_LIVING_BRAIN.md الشريحة ٩).
//
// المالك (٢٠٢٦-١٠-٠٣): العقل يسأل نفسه «إيه أصغر حاجة أعملها بكرة تقرّب البيت من هدفه؟». الأهداف
// موجودة (agent_goals، العميل هو اللي بيحطها) ومتابعتها الأسبوعية بالموديل موجودة (agent_tasks
// kind = goal_review)؛ الناقص كان رقم يقول «متأخر» — من غيره العقل بيشجّع هدف واقف أو بيقلق على هدف
// ماشي كويس. الحساب هنا خطي على الوقت: المتوقع لحد النهارده = الهدف × (اللي عدى ÷ المدة كلها).

const DAY_MS = 86_400_000;

export type GoalPace = "done" | "early" | "on_track" | "behind" | "overdue";

export interface GoalPaceInput {
  target_value: number | string | null;
  current_value: number | string | null;
  deadline_date: string | null;
  created_at: string | null;
}

export interface GoalPaceResult {
  pace: GoalPace;
  /** المفروض يكون وصل كام لحد النهارده (رقم عشري واحد). */
  expected_by_now: number;
  days_left: number;
}

/**
 * null = الهدف مالوش رقم أو ميعاد (مفيش جدول يتقاس عليه). «early» = عدى أقل من ١٠٪ من المدة —
 * بدري نحكم. «behind» محتاج فرق حقيقي: وحدة كاملة على الأقل أو ١٥٪ من الهدف، عشان هدف أسبوعي
 * (٢ من ١٢ وميعاد التالت بكرة) مايبانش متأخر من تقريب خطي.
 */
export function goalPace(goal: GoalPaceInput, now: Date = new Date()): GoalPaceResult | null {
  const target = Number(goal.target_value);
  const current = Number(goal.current_value ?? 0);
  const start = goal.created_at ? Date.parse(goal.created_at) : NaN;
  const end = goal.deadline_date ? Date.parse(`${goal.deadline_date}T23:59:59Z`) : NaN;
  if (!(target > 0) || !Number.isFinite(current) || !Number.isFinite(start) || !Number.isFinite(end) || end <= start) {
    return null;
  }
  const t = now.getTime();
  const fraction = Math.min(1, Math.max(0, (t - start) / (end - start)));
  const expected = Math.round(target * fraction * 10) / 10;
  const daysLeft = Math.max(0, Math.ceil((end - t) / DAY_MS));
  let pace: GoalPace;
  if (current >= target) pace = "done";
  else if (t > end) pace = "overdue";
  else if (fraction < 0.1) pace = "early";
  else if (expected - current >= Math.max(1, 0.15 * target)) pace = "behind";
  else pace = "on_track";
  return { pace, expected_by_now: expected, days_left: daysLeft };
}
