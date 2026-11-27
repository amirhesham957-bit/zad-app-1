/**
 * هدف الفرد بخطوات بتتقاس وبتتعدّل لوحدها لو وقف (ZAD_OR_PLAN م٧.٨). دوال صافية.
 * الهدف = رقم مستهدف على مدة؛ الخطوة = حصة أسبوعية. «وقف» = أسبوعين ورا بعض تحت نص الحصة الأصلية.
 */

export interface GoalInput {
  target: number;
  weeks: number;
  /** المحقق في كل أسبوع منقضي بالترتيب (مش تراكمي). */
  weeklyProgress: readonly number[];
}

export interface GoalStatus {
  done: number;
  remaining: number;
  weeksLeft: number;
  stepPerWeek: number;
  stalled: boolean;
  met: boolean;
}

const STALL_RATIO = 0.5;
const STALL_WEEKS = 2;
const MAX_EXTEND_WEEKS = 8;

export function goalStatus(g: GoalInput): GoalStatus {
  const done = g.weeklyProgress.reduce((a, b) => a + Math.max(0, b), 0);
  const remaining = Math.max(0, g.target - done);
  const weeksLeft = Math.max(0, g.weeks - g.weeklyProgress.length);
  const initialStep = g.weeks > 0 ? g.target / g.weeks : g.target;
  const stepPerWeek = weeksLeft > 0 ? remaining / weeksLeft : remaining;
  const recent = g.weeklyProgress.slice(-STALL_WEEKS);
  const stalled = remaining > 0 && recent.length === STALL_WEEKS &&
    recent.every((p) => p < initialStep * STALL_RATIO);
  return { done, remaining, weeksLeft, stepPerWeek, stalled, met: remaining === 0 };
}

export interface GoalAdjustment {
  kind: "none" | "extend_deadline";
  stepPerWeek: number;
  weeks: number;
  reason: string;
}

/**
 * لو وقف: بنمدّد المدة (أقصى ٨ أسابيع) فتنزل الخطوة الأسبوعية. الرقم المستهدف نفسه مابيتغيّرش؛ ده قرار الفرد.
 * الإضافة بتتحسب من الوتيرة الفعلية الأخيرة × ١٫٢٥ (واقعية)، مش من الخطوة الأصلية.
 */
export function adjustStalledGoal(g: GoalInput): GoalAdjustment {
  const s = goalStatus(g);
  if (!s.stalled) return { kind: "none", stepPerWeek: s.stepPerWeek, weeks: g.weeks, reason: "on_track" };
  const recent = g.weeklyProgress.slice(-STALL_WEEKS);
  const avg = recent.reduce((a, b) => a + Math.max(0, b), 0) / recent.length;
  const realistic = Math.max(avg * 1.25, 1e-9);
  const needWeeks = Math.ceil(s.remaining / realistic);
  const add = Math.min(MAX_EXTEND_WEEKS, Math.max(1, needWeeks - s.weeksLeft));
  const weeks = g.weeks + add;
  return {
    kind: "extend_deadline",
    stepPerWeek: s.remaining / (s.weeksLeft + add),
    weeks,
    reason: "stalled",
  };
}
