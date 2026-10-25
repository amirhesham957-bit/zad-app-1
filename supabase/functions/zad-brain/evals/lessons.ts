// evals/lessons.ts — التصحيح بيبقى درس (ZAD_PLAN ٣.١١).
//
// كل مرة العميل غيّر فئة حركة (zad_corrections، kind = category) بيبقى درس: «اكتب {الموضوع}» ⇒ لازم يتقترح
// تسجيل بالفئة اللي العميل اختارها. zad_eval_lesson_cases بيدّي أحدث درس لكل موضوع من غير صاحبه، والموضوع
// متنقّح (zad_redact_lesson). الدروس بتشتغل بعد الـ٢٠٠ حالة بفئة lesson، ونسبتها لوحدها برّه أخضر/أحمر:
// حساب الاختبار مالوش ذاكرة البيت اللي اتعلّم، فالنسبة بتقول الدرس وصل للعقل كله ولا لسه عند بيته بس.

import type { EvalCase } from "./judge.ts";

export const LESSONS_PER_NIGHT = 30;

/** صف zad_eval_lesson_cases ⇒ حالة، أو null لو ناقص. نفس الرقم لكل درس عشان الفرق يبقى الموضوع بس. */
export function lessonCase(row: { id?: unknown; subject?: unknown; right_answer?: unknown }): EvalCase | null {
  const id = String(row.id ?? "").replace(/[^0-9a-f]/gi, "").slice(0, 12);
  const subject = String(row.subject ?? "").replace(/\s+/g, " ").trim();
  const right = String(row.right_answer ?? "").trim();
  if (!id || !subject || !right) return null;
  return {
    id: `lesson_${id}`, category: "lesson", message: `سجل 50 ${subject}`,
    expect: { proposes: "log_transaction", input: { amount: 50, category: right } },
  };
}
