// familyTime.ts — وقت العيلة قبل الويك إند (الموجة ٤ من «خطة سد الفجوات»: «الترابط العائلي — مااتبناش»).
//
// الخطة سمّت البند من غير ما تحدده، فده التعريف اللي اتبنى (ZAD_LIVING_BRAIN.md §١٧): مرة في الأسبوع، في تحية صبح اليوم
// اللي قبل الويك إند، بيت فيه أكتر من فرد بياخد اقتراح وقت سوا — خروجة لو جو أول يوم في الويك إند حلو، وقعدة في البيت لو
// مش للخروج. الفلوس من نفس حسبة ميزان الرفاهية (الشريحة ٣١، wellbeing.ts): سقف من اللي اتوفّر، وإلا أفكار ببلاش. قواعد مش
// موديل، صفر توكنز. ومفيش أي تتبع لحد في العيلة — الاقتراح للي بيستلم التحية بس.
//
// مابيتقالش في ظرف (الشريحة ٢٩). الميزانية في خطر أو «أنا مفلس» ⇒ أفكار ببلاش بس، من غير مبلغ.

import type { DayWeather } from "./weather.ts";
import { activityBudget, savedSoFar } from "./wellbeing.ts";

/** أول يوم في الويك إند (0 = الحد … 5 = الجمعة، 6 = السبت). الافتراضي الجمعة (مصر والخليج والشام والعراق). */
const WEEKEND_FIRST_DAY: Record<string, number> = { MA: 6, TN: 6, TR: 6, LB: 6 };

export const OUTDOOR_MIN_C = 18;
export const OUTDOOR_MAX_C = 34;

/** يوم الأسبوع لتاريخ مدني YYYY-MM-DD (0 = الحد). */
function weekday(date: string): number {
  return new Date(`${date}T12:00:00Z`).getUTCDay();
}

function addDays(date: string, n: number): string {
  return new Date(Date.parse(`${date}T12:00:00Z`) + n * 86_400_000).toISOString().slice(0, 10);
}

/** النهارده اليوم اللي قبل الويك إند في بلده؟ */
export function isWeekendEve(date: string, country: string | null | undefined): boolean {
  const first = WEEKEND_FIRST_DAY[String(country ?? "").toUpperCase()] ?? 5;
  return (weekday(date) + 1) % 7 === first;
}

/** بيت فيه أكتر من فرد: عيلة في التطبيق، أو عيال، أو عدد البيت من «ملفي». */
export function isFamilyHome(o: { familyMembers: number; kidsCount?: number | null; householdSize?: number | null }): boolean {
  return o.familyMembers >= 2 || (o.kidsCount ?? 0) >= 1 || (o.householdSize ?? 0) >= 2;
}

/** جو ينفع للخروج: من غير عواصف ولا مطر، وبين ١٨° و٣٤°، والريح أقل من ٤٠. */
export function outdoorDay(d: DayWeather | undefined | null): boolean {
  return !!d && d.code < 51 && d.rain_mm < 1 && d.max >= OUTDOOR_MIN_C && d.max <= OUTDOOR_MAX_C && d.wind_kmh < 40;
}

export interface FamilyTime {
  outdoor: boolean;
  /** سقف من اللي اتوفّر، أو null = أفكار ببلاش. */
  budget: number | null;
  currency: string | null;
  line: string;
}

/**
 * الاقتراح، أو null (مش اليوم اللي قبل الويك إند، أو مش بيت فيه أكتر من فرد). [tight] = الميزانية في خطر أو «أنا مفلس».
 */
export function familyTime(o: {
  date: string;
  country: string | null | undefined;
  family: { familyMembers: number; kidsCount?: number | null; householdSize?: number | null };
  days?: readonly DayWeather[] | null;
  budget?: { threat?: string | null; velocity?: number | null; spent?: number | null; available?: number | null; currency?: string | null } | null;
  tight: boolean;
}): FamilyTime | null {
  if (!isWeekendEve(o.date, o.country) || !isFamilyHome(o.family)) return null;
  const weekendDay = o.days?.find((d) => d.date === addDays(o.date, 1)) ?? null;
  const outdoor = outdoorDay(weekendDay);
  const saved = o.tight || !o.budget ? null : savedSoFar(o.budget);
  const budget = saved === null ? null : activityBudget(saved, Number(o.budget?.available));
  const currency = o.budget?.currency ?? null;
  const money = budget ? ` في حدود ${budget}${currency ? ` ${currency}` : ""} من اللي اتوفّر` : " ببلاش";
  const line = outdoor && weekendDay
    ? `بكرة الجو حلو (${weekendDay.label}، العظمى ${weekendDay.max}°) — خروجة عيلة؟ جنينة أو تمشية أو فطار برّه${money}.`
    : weekendDay
      ? `بكرة الجو مش للخروج (${weekendDay.label}، ${weekendDay.max}°) — قعدة عيلة في البيت؟ فيلم وفشار، لعبة سوا، أو تطبخوا حاجة مع بعض${money}.`
      : `آخر الأسبوع جه — وقت عيلة سوا؟ خروجة قريبة أو قعدة في البيت${money}.`;
  return { outdoor, budget, currency, line };
}
