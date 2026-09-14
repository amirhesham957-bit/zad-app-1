// تحدي ٣٠ يوم توفير (20260914010000) — منطق مشترك (العقل + التست). نفس الحساب في
// SavingsChallengeMath.kt على الموبايل.

/**
 * السقف اليومي المقترح لو العميل ماحددش: ٨٠٪ من متوسط صرفه اليومي آخر ٣٠ يوم (تحدي حقيقي
 * بس ممكن)، ولو مفيش تاريخ صرف: ٩٠٪ من مصروف اليوم المتاح. `null` = مفيش أساس — لازم يقول رقم.
 */
export function suggestChallengeCap(input: { avgDailySpend: number | null; dailyAllowanceLeft: number | null }): number | null {
  const avg = Number(input.avgDailySpend);
  if (Number.isFinite(avg) && avg > 0) return Math.max(1, Math.round(avg * 0.8));
  const allowance = Number(input.dailyAllowanceLeft);
  if (Number.isFinite(allowance) && allowance > 0) return Math.max(1, Math.floor(allowance * 0.9));
  return null;
}

/** اليوم رقم كام في التحدي (١ = يوم البداية)، بالتاريخ المحلي. */
export function challengeDayIndex(startedOn: string, localDate: string): number {
  const start = Date.parse(`${startedOn}T00:00:00Z`);
  const today = Date.parse(`${localDate}T00:00:00Z`);
  if (!Number.isFinite(start) || !Number.isFinite(today)) return 1;
  return Math.max(1, Math.floor((today - start) / 86_400_000) + 1);
}
