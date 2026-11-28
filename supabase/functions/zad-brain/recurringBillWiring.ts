// P3.6: ربط كاشف المصاريف الثابتة (`_shared/or/recurringBills.ts`) بمسار الاقتراح الموجود: `obligation_detection` ← سؤال ← `confirm_obligation`
// ← `commitIntent` (الباب). مابيكتبش هنا. خلف ZAD_RECURRING_BILLS (مقفول افتراضياً).
// confirm_obligation بيكتب recurrence=monthly دايماً، فالمرشح الشهري بس هو اللي بيعدّي (الأسبوعي/كل أسبوعين بيتكشفوا بس).
import { detectRecurringBills, type BankTxn } from "../_shared/or/recurringBills.ts";
import { hashKey } from "./hashKey.ts";

export const RECURRING_BILLS_FLAG = "ZAD_RECURRING_BILLS";

export function recurringBillsOn(): boolean {
  const v = Deno.env.get(RECURRING_BILLS_FLAG);
  return v === "1" || v === "true";
}

export function recurringObligationCandidate(
  expenseTx: readonly BankTxn[],
  known: readonly string[],
  now: Date,
  enabled = recurringBillsOn(),
): { title: string; amount: number; due_day: number; dedupe_key: string } | null {
  if (!enabled) return null;
  const c = detectRecurringBills(expenseTx, known, now).find((x) => x.period === "monthly");
  if (!c) return null;
  return {
    title: c.merchant,
    amount: c.amount,
    due_day: c.dueDay,
    dedupe_key: `obligation_confirm_${hashKey(`${c.merchant}_${c.amount}`)}`,
  };
}
