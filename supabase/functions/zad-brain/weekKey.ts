/**
 * Task 19.5 — مفتاح ثابت لكل أسبوع تقويمي (ISO week)، محسوب هنا في الكود مش من الموديل،
 * عشان upsert بـ (user_id, dedupe_key) يبقى idempotent فعلاً لو الموديل قرر يسأل أكتر
 * من مرة في نفس الأسبوع (بيرجع نفس الصف pending، مش يكرره)، ونفس المبدأ اللي
 * suggest_budget_change بيستخدمه لمفتاحه الشهري — الموديل ميحسبش مفاتيح زمنية بنفسه.
 */
export function isoWeekKey(d: Date): string {
  const date = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
  const dayNum = date.getUTCDay() || 7;
  date.setUTCDate(date.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1));
  const weekNo = Math.ceil((((date.getTime() - yearStart.getTime()) / 86400000) + 1) / 7);
  return `cash_reconciliation_${date.getUTCFullYear()}_w${weekNo}`;
}
