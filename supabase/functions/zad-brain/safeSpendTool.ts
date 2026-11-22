// م٣.٥ (ZAD_OR_PLAN): «أصرف كام النهارده؟» — أداة بالطلب فوق `_shared/or/safeSpend.ts`.
//
// المتاح وأيام القبض من zad_budget_state (المرجع الوحيد للفلوس)، والمتاح فيه الالتزامات محجوزة أصلاً، فبنعدّيها
// للمحرك صفر (نفس منطق paydayOdds.ts). مفيش هامش في أي بيانات عندنا، فالهامش صفر ومش مخترع.
// قبل ١٤ يوم صرف: من غير احتمال، والرقم «تقريباً».

import { MIN_HISTORY_DAYS, safeSpendToday } from "../_shared/or/safeSpend.ts";
import { dailySpendSeries, type SpendRow } from "./paydayOdds.ts";

export interface SafeSpendState {
  available?: number | null;
  days_left?: number | null;
  currency?: string | null;
}

export function describeSafeSpend(state: SafeSpendState | null, rows: readonly SpendRow[], today: string, timeZone: string): string {
  const available = state?.available;
  if (available === null || available === undefined || !Number.isFinite(Number(available))) {
    return "مفيش سقف شهري متسجل، فمفيش مصروف آمن أحسبه — قول للعميل كده واسأله عن ميزانيته.";
  }
  const cur = state?.currency ? ` ${state.currency}` : "";
  const days = Math.max(1, Math.floor(Number(state?.days_left) || 1));
  if (Number(available) <= 0) {
    return `المتاح خلص (${Math.round(Number(available))}${cur}) — مفيش مصروف آمن النهارده. قول للعميل كده بهدوء.\nالأرقام دي بس اللي تتقال.`;
  }
  const { series, spendDays } = dailySpendSeries(rows, today, timeZone);
  const r = safeSpendToday({
    available: Number(available), obligationsUntilPayday: 0, margin: 0, daysUntilPayday: days, spendHistory: series,
  });
  const lines = [`مصروف النهارده الآمن: ${Math.round(r.perDay)}${cur} في اليوم لـ${days} يوم لحد القبض (المتاح بعد الالتزامات).`];
  if (r.approximate || spendDays < MIN_HISTORY_DAYS) {
    lines.push(`الرقم تقريباً: لسه أقل من ${MIN_HISTORY_DAYS} يوم صرف متسجل، فمفيش احتمال أقوله.`);
  } else {
    const pct = Math.round((r.reachProbability ?? 0) * 10) * 10;
    lines.push(`لو صرفه زي عادة آخر ٢٨ يوم، احتمال يوصل للقبض من غير ما يعدّي المتاح حوالي ${pct}٪ (محاكاة ${r.paths} مسار).`);
  }
  lines.push("الأرقام دي بس اللي تتقال.");
  return lines.join("\n");
}
