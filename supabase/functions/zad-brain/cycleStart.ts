/**
 * راتب متجمّع على يوم معين ± ٣ أيام على مدار آخر ٤ شهور = مرشح قوي لدورة راتب. بيرجع null
 * لو مفيش تجمّع واضح (أقل من نصف معاملات الدخل المرصودة، أو أقل من معاملتين) — بلا تخمين
 * ضعيف. الاختيار هنا بسيط عمداً (mode-like clustering)، مش إحصاء متقدم — العميل بيأكد
 * بنفسه قبل ما الرقم يتسجل، فمفيش داعي لدقة زايدة هنا.
 */
export function detectCycleStartDay(incomeTx: Array<{ created_at: string }>): number | null {
  if (incomeTx.length < 2) return null;
  const days = incomeTx.map((t) => new Date(t.created_at).getDate());
  let bestDay: number | null = null;
  let bestCount = 0;
  for (const candidate of days) {
    const count = days.filter((d) => Math.abs(d - candidate) <= 3).length;
    if (count > bestCount) {
      bestCount = count;
      bestDay = candidate;
    }
  }
  if (bestDay === null || bestCount < 2 || bestCount < days.length / 2) return null;
  return bestDay;
}
