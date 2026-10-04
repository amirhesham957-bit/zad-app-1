// longMemory.ts — ذاكرة البيت الطويلة (ZAD_LIVING_BRAIN.md الشريحة ٢٧، من «نفذ كامل البرومبت»).
//
// فكرتين اتأجلوا في §٩ عشان الداتا قصيرة («كبسولة الذكريات» و«ذاكرة الصمود»). الاتنين هنا **بيصحوا لوحدهم** لما
// التاريخ يبقى كفاية — قبلها بيرجعوا null ومحدش بيشوف حاجة، ومفيش رقم مخترع.
//
//   - **زي النهارده من سنة:** حقيقة قالها العميل (scope general) أو هدف حققه من سنة بالظبط (±يوم) ⇒ ملاحظة خفيفة من
//     مدرّب «brain» (أقل وزن في منسّق الانتباه). أول يوم ممكن: أغسطس ٢٠٢٧ (الداتا من أغسطس ٢٠٢٦). ذكرى حزينة أو حساسة
//     (مرض، وفاة، مستشفى، ضيقة…) مابتطلعش — «زي النهارده» لحاجة حلوة بس.
//   - **الصمود:** الشهور اللي المصاريف فيها عدّت الدخل بأكتر من ١٠٪، وكل واحد البيت رجع منه في كام شهر (الفايض بعده غطّى
//     العجز). بيتحسب بالطلب (أداة household_resilience) لما العميل يقلق من شهر صعب — حقيقة من تاريخه مش وعظ. أقل من ٦
//     شهور كاملة ⇒ null.

import type { StaffNote } from "./staff.ts";
import { SENSITIVE_TRAIT } from "./consolidation.ts";

const DAY = 86_400_000;

/** ذكرى مش حلوة — مابتتقالش «زي النهارده». */
const SAD = /وفاة|توفى|توفي|اتوفى|مات |ماتت|عزاء|حادث|مستشفى|عملية|طوارئ|اتسرق|خساره|خسارة|خناقة|زعل/;

export interface CapsuleMemory { note: string; scope: string | null; created_at: string }
export interface CapsuleGoal { title: string; updated_at: string | null }

/** ملاحظة «زي النهارده من سنة» أو null. [now] بالـms، والسنة = ٣٦٥ يوم ±١. */
export function capsuleNote(memories: readonly CapsuleMemory[], goals: readonly CapsuleGoal[], now: number): StaffNote | null {
  const yearAgo = now - 365 * DAY;
  const near = (iso: string | null) => {
    const at = Date.parse(String(iso ?? ""));
    return Number.isFinite(at) && Math.abs(at - yearAgo) <= DAY;
  };
  const goal = goals.find((g) => near(g.updated_at) && g.title.trim());
  const memory = memories.find((m) =>
    (m.scope ?? "general") === "general" && near(m.created_at) &&
    !SAD.test(m.note) && !SENSITIVE_TRAIT.test(m.note) && m.note.trim().length >= 8
  );
  if (!goal && !memory) return null;
  const day = new Date(yearAgo).toISOString().slice(0, 10);
  const parts: string[] = [];
  if (goal) parts.push(`من سنة حقق هدف «${goal.title.trim().slice(0, 60)}»`);
  if (memory) parts.push(`من سنة كان قايل: «${memory.note.trim().slice(0, 160)}»`);
  return {
    sender: "brain",
    subject: `زي النهارده من سنة (${day})`,
    detail: `${parts.join("؛ ")}. لو الكلام جه على حاجة قريبة، افتكرها معاه بجملة دافية — من غير ما تفتحها موضوع لوحدها، ` +
      "ومن غير ما تحسب «اتغيّرت قد إيه».",
  };
}

export interface MonthTxn { amount: number | null; is_expense: boolean | null; txn_kind: string | null; created_at: string }
export interface MonthTotal { month: string; income: number; spend: number }

/** الدخل والمصاريف لكل شهر (YYYY-MM)، الأقدم الأول. نفس تصنيف monthlyAverages. */
export function monthlyTotals(txns: readonly MonthTxn[]): MonthTotal[] {
  const by = new Map<string, MonthTotal>();
  for (const t of txns) {
    const month = String(t.created_at ?? "").slice(0, 7);
    if (!/^\d{4}-\d{2}$/.test(month)) continue;
    const row = by.get(month) ?? { month, income: 0, spend: 0 };
    const amount = Math.max(0, Number.isFinite(Number(t.amount)) ? Number(t.amount) : 0);
    if (t.txn_kind === "income" || t.is_expense === false) row.income += amount;
    else if (!t.txn_kind || t.txn_kind === "expense") row.spend += amount;
    by.set(month, row);
  }
  return [...by.values()].sort((a, b) => a.month.localeCompare(b.month));
}

/** أقل شهور كاملة عشان الصمود يتقال. */
export const RESILIENCE_MIN_MONTHS = 6;

export interface Resilience {
  months_of_history: number;
  hard_months: Array<{ month: string; deficit: number; recovered_in: number | null }>;
  /** الوسيط لكل شهر صعب رجع منه؛ null لو مفيش ولا واحد رجع لسه. */
  typical_recovery_months: number | null;
}

/**
 * الشهور الكاملة بس (الشهر الحالي [currentMonth] برّه — لسه مخلصش). شهر صعب = المصاريف عدّت الدخل بأكتر من ١٠٪ من الدخل
 * (ولو مفيش دخل خالص في الشهر، مابيتحسبش: غالباً المرتب مابيتسجلش، مش أزمة). الرجوع = أول شهر الفايض المتراكم بعده
 * غطّى العجز.
 */
export function resilience(months: readonly MonthTotal[], currentMonth: string): Resilience | null {
  const complete = months.filter((m) => m.month < currentMonth);
  if (complete.length < RESILIENCE_MIN_MONTHS) return null;
  const hard: Resilience["hard_months"] = [];
  for (const [i, m] of complete.entries()) {
    if (m.income <= 0 || m.spend <= m.income * 1.1) continue;
    const deficit = m.spend - m.income;
    let covered = 0;
    let recoveredIn: number | null = null;
    for (let j = i + 1; j < complete.length; j++) {
      covered += complete[j].income - complete[j].spend;
      if (covered >= deficit) {
        recoveredIn = j - i;
        break;
      }
    }
    hard.push({ month: m.month, deficit: Math.round(deficit), recovered_in: recoveredIn });
  }
  const recovered = hard.map((h) => h.recovered_in).filter((n): n is number => n !== null).sort((a, b) => a - b);
  return {
    months_of_history: complete.length,
    hard_months: hard.slice(-6),
    typical_recovery_months: recovered.length ? recovered[Math.floor((recovered.length - 1) / 2)] : null,
  };
}
