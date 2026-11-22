// حالة الرحلة (م٧.١): بنحسب اليوم اللي إحنا فيه من الرحلة، والأيام اللي فاضلة، والميزانية اللي فاضلة لكل يوم.
// كل المقارنات بتتم على أيام التقويم بتوقيت UTC (أول ١٠ حروف من التاريخ بس)، عشان الساعة ماتلخبطش الحساب.
// دالة نقية: مافيش I/O.

export interface TripInput {
  startISO: string;
  endISO: string;
  todayISO: string;
  budget: number;
  spent: number;
}

const DAY_MS = 86_400_000;

/** بنحوّل التاريخ لرقم يوم تقويمي (UTC) عشان نطرح بيهم. */
function dayNumber(iso: string): number {
  return Date.parse(`${iso.slice(0, 10)}T00:00:00Z`) / DAY_MS;
}

export function tripState(i: TripInput): {
  day: number;
  of: number;
  daysLeft: number;
  remaining: number;
  perDayLeft: number;
  overBudget: boolean;
} {
  const start = dayNumber(i.startISO);
  const end = dayNumber(i.endISO);
  const today = dayNumber(i.todayISO);

  // عدد أيام الرحلة، والبداية والنهاية داخلين في العدد.
  const of = end - start + 1;
  // اليوم الحالي جوه الرحلة. لو الرحلة لسه متبدأتش يبقى اليوم الأول، ولو خلصت يبقى آخر يوم.
  const day = Math.min(Math.max(today - start + 1, 1), of);
  // الأيام الفاضلة من النهارده لحد آخر يوم. ولو الرحلة خلصت خالص يبقى صفر.
  const daysLeft = today > end ? 0 : Math.max(0, of - day + 1);

  const remaining = i.budget - i.spent;
  // الميزانية اللي من حقنا نصرفها في اليوم الواحد من الباقي، متقربة لقرشين.
  const perDayLeft = daysLeft > 0 ? Math.round((remaining / daysLeft) * 100) / 100 : 0;
  const overBudget = remaining < 0;

  return { day, of, daysLeft, remaining, perDayLeft, overBudget };
}
