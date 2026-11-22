// «مصروف النهارده الآمن» واحتمال الوصول للقبض (ZAD_OR_PLAN م٣.٥).
//
// المصروف اليومي نفسه مابيتحسبش هنا: zad_budget_state() هو المرجع الوحيد للفلوس، وده بيرجّع
// `daily_allowance_left` = available ÷ days_left. الجديد هنا حاجتين بس:
//   • `approximate`: قبل ١٤ يوم صرف متسجل، الرقم «تقريباً» ومفيش احتمال.
//   • `reach_probability`: Monte Carlo (١٠٠٠ مسار، `_shared/or/safeSpend.ts`) على أيام الصرف اللي اتقفلت، لحد يوم القبض.
//
// ليه «١٤ يوم فيهم صرف» مش «١٤ يوم من أول معاملة»: اتقاس على الحي ٢١/١١، كل الحسابات اللي صرفت في آخر ٢٨ يوم
// عندها ٧ أيام صرف بالكتير (الوسيط يوم واحد). لو اليوم اللي مفيهوش تسجيل اتحسب صرف صفر، المحاكاة هتقول لحد مابيسجلش
// «هتوصل للقبض بنسبة ٩٩٪». ده أمان كاذب في الفلوس.
// ومدفوعات الالتزامات (`linked_obligation_id`) بتتشال من التاريخ، لأن اللي لسه ماتدفعش منها محجوز في `committed` أصلاً.

import { MIN_HISTORY_DAYS, safeSpendToday } from "../_shared/or/safeSpend.ts";

export const HISTORY_WINDOW_DAYS = 28;

export interface SpendRow {
  amount: number | string | null;
  txn_kind?: string | null;
  is_expense?: boolean | null;
  created_at: string;
  linked_obligation_id?: string | null;
}

export interface PaydayOdds {
  approximate: boolean;
  reach_probability: number | null;
  spend_days: number;
}

function civilDate(iso: string, timeZone: string): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" })
    .format(new Date(iso));
}

function addDays(date: string, n: number): string {
  const [y, m, d] = date.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d + n)).toISOString().slice(0, 10);
}

/**
 * Discretionary spend per civil day (account zone) over the last HISTORY_WINDOW_DAYS completed days, oldest first.
 * Days run from the first day with spending to yesterday; a day with nothing recorded inside that span counts as 0.
 */
export function dailySpendSeries(rows: readonly SpendRow[], today: string, timeZone: string): { series: number[]; spendDays: number } {
  const from = addDays(today, -HISTORY_WINDOW_DAYS);
  const byDay = new Map<string, number>();
  for (const r of rows) {
    const expense = r.txn_kind ? r.txn_kind === "expense" : r.is_expense === true;
    const amount = Number(r.amount);
    if (!expense || r.linked_obligation_id || !Number.isFinite(amount) || amount <= 0) continue;
    const day = civilDate(r.created_at, timeZone);
    if (day < from || day >= today) continue;
    byDay.set(day, (byDay.get(day) ?? 0) + amount);
  }
  if (byDay.size === 0) return { series: [], spendDays: 0 };
  const first = [...byDay.keys()].sort()[0];
  const series: number[] = [];
  for (let d = first; d < today; d = addDays(d, 1)) series.push(Math.round((byDay.get(d) ?? 0) * 100) / 100);
  return { series, spendDays: byDay.size };
}

/**
 * `available` and `daysLeft` come straight from zad_budget_state. No ceiling (available null) → nothing to judge.
 */
export function paydayOdds(
  available: number | null | undefined,
  daysLeft: number | null | undefined,
  rows: readonly SpendRow[],
  today: string,
  timeZone: string,
): PaydayOdds | null {
  if (available === null || available === undefined || !Number.isFinite(available)) return null;
  const { series, spendDays } = dailySpendSeries(rows, today, timeZone);
  if (spendDays < MIN_HISTORY_DAYS) return { approximate: true, reach_probability: null, spend_days: spendDays };
  // صفر أو سالب = الفلوس اتصرفت خلاص. مايتسابش لمسار كل أيامه صفر يقول «هتوصل».
  if (available <= 0) return { approximate: false, reach_probability: 0, spend_days: spendDays };
  const r = safeSpendToday({
    available,
    obligationsUntilPayday: 0, // محجوزة في available أصلاً
    margin: 0,
    daysUntilPayday: Math.max(1, Number(daysLeft) || 1),
    spendHistory: series,
  });
  return { approximate: false, reach_probability: r.reachProbability, spend_days: spendDays };
}

/** قاعدة البرومبت. "" لو مفيش سقف. */
export function paydayOddsRule(snap: { payday_odds?: PaydayOdds | null } | null | undefined): string {
  const o = snap?.payday_odds;
  if (!o) return "";
  if (o.approximate) {
    return "**payday_odds.approximate** = أقل من ١٤ يوم صرف متسجل: لو قلت مصروف النهارده (daily_allowance_left) قول «تقريباً» جنبه، " +
      "وماتقولش أي احتمال أو نسبة للوصول للقبض.";
  }
  return "**payday_odds.reach_probability** = احتمال إن الصرف بنفس عادة آخر ٢٨ يوم يوصل لحد القبض من غير ما يعدّي المتاح " +
    "(محاكاة ١٠٠٠ مسار، مش رأي). لو اتسأل «هكمّل الشهر؟» أو حاجة شبهه، قوله كنسبة مقرّبة لأقرب ١٠٪، وماتغيّرش daily_allowance_left بسببه.";
}
