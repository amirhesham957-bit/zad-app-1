// handover.ts — كارت تسليم الشفت (ZAD_LIVING_BRAIN.md §١٠ والشريحة ٣٤، قرار المالك ٢٠٢٦-١٠-٠٥).
//
// «بطاقة تسليم فورية بين الزوجين عند سفر أحدهما: الأدوية، المواعيد، والميزانية». الحاجات دي موجودة على جداول متفرقة —
// الصيدلية (ولمين)، المواعيد، جدول الحصص (الشريحة ٢١)، حساب الميزانية، الالتزامات، وقايمة التسوق. هنا بتتجمع للأيام الجاية
// في كارت واحد يتبعت للي فاضل في البيت.
//
// **من حساب العميل نفسه بس** — هو اللي بيسلّم بياناته. مفيش موقع ولا متابعة لحد (ZAD_LIVING_BRAIN.md §٣: تتبع البالغ ممنوع حتى
// بموافقته)، ومفيش قراية من حساب الطرف التاني. حساب حتمي، صفر توكنز.

import { AMBULANCE_NUMBERS } from "./emergency.ts";

export const HANDOVER_DEFAULT_DAYS = 3;
export const HANDOVER_MAX_DAYS = 14;

export interface HandoverInput {
  /** النهارده بتوقيت السوق (YYYY-MM-DD). */
  today: string;
  /** منطقة السوق — يوم الميعاد بيتحسب بيها. */
  timeZone: string;
  days: number;
  country: string | null;
  currency: string | null;
  medicines: ReadonlyArray<{
    name: string; dosage: string | null; dose_times: string | null; remaining_quantity: number | null;
    daily_dose_count: number | null; units_per_dose?: number | null; for_person: string | null; is_recurring: boolean | null;
  }>;
  /** المواعيد اللي جاية، starts_at بتوقيت فيه منطقة. */
  appointments: ReadonlyArray<{ title: string; starts_at: string; kind: string | null; for_person: string | null }>;
  timetable: ReadonlyArray<{ person: string; weekday: number; period: number; subject: string; starts: string | null }>;
  budget: { daily_allowance_left: number | null; available: number | null } | null;
  obligations: ReadonlyArray<{ title: string; amount: number | null; due_day: number | null }>;
  shopping: readonly string[];
}

export interface HandoverCard {
  days: number;
  from: string;
  to: string;
  ambulance: string | null;
  doses: Array<{ who: string; name: string; dosage: string | null; times: string; days_left: number | null }>;
  running_low: string[];
  appointments: Array<{ who: string; title: string; starts_at: string }>;
  school: Array<{ day: string; person: string; subjects: string[]; first_period: string | null }>;
  money: { per_day: number | null; available: number | null; currency: string | null; due: Array<{ title: string; amount: number | null; day: string }> };
  shopping: string[];
}

const DAY = 86_400_000;
const WEEKDAYS = ["الأحد", "الاتنين", "التلات", "الأربع", "الخميس", "الجمعة", "السبت"];

/** YYYY-MM-DD + n يوم. */
export function addDays(date: string, n: number): string {
  return new Date(Date.parse(`${date}T00:00:00Z`) + n * DAY).toISOString().slice(0, 10);
}

/** اليوم المحلي (YYYY-MM-DD) للحظة [iso] في [timeZone]. */
export function localDate(iso: string, timeZone: string): string | null {
  const t = Date.parse(iso);
  if (!Number.isFinite(t)) return null;
  try {
    return new Intl.DateTimeFormat("en-CA", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date(t));
  } catch {
    return new Date(t).toISOString().slice(0, 10);
  }
}

function weekdayOf(date: string): number {
  return new Date(`${date}T00:00:00Z`).getUTCDay();
}

/** الأيام الفاضلة في الدوا بمعدله، أو null لو مش معروف. */
function daysOfMedicine(m: HandoverInput["medicines"][number]): number | null {
  const perDay = (Number(m.daily_dose_count) || 0) * (Number(m.units_per_dose) || 1);
  if (perDay <= 0 || m.remaining_quantity === null || m.remaining_quantity === undefined) return null;
  return Math.floor(Number(m.remaining_quantity) / perDay);
}

export function handoverCard(input: HandoverInput): HandoverCard {
  const days = Math.min(HANDOVER_MAX_DAYS, Math.max(1, Math.round(input.days) || HANDOVER_DEFAULT_DAYS));
  const from = input.today;
  const to = addDays(from, days - 1);
  const dates = Array.from({ length: days }, (_, i) => addDays(from, i));

  const scheduled = input.medicines.filter((m) => String(m.dose_times ?? "").trim());
  const doses = scheduled.map((m) => ({
    who: (m.for_person ?? "").trim() || "العميل نفسه",
    name: m.name,
    dosage: m.dosage,
    times: String(m.dose_times),
    days_left: daysOfMedicine(m),
  }));
  // هيخلص قبل ما الشفت يخلص (أو معاه) ⇒ لازم يتجاب.
  const running_low = doses.filter((d) => d.days_left !== null && d.days_left <= days).map((d) => `${d.name} (${d.who})`);

  const appointments = input.appointments
    .filter((a) => {
      const day = localDate(a.starts_at, input.timeZone);
      return day !== null && day >= from && day <= to;
    })
    .sort((a, b) => a.starts_at.localeCompare(b.starts_at))
    .map((a) => ({ who: (a.for_person ?? "").trim() || "العميل نفسه", title: a.title, starts_at: a.starts_at }));

  const school: HandoverCard["school"] = [];
  for (const date of dates) {
    const wd = weekdayOf(date);
    const people = [...new Set(input.timetable.filter((p) => p.weekday === wd).map((p) => p.person))];
    for (const person of people) {
      const periods = input.timetable.filter((p) => p.weekday === wd && p.person === person).sort((a, b) => a.period - b.period);
      school.push({
        day: `${WEEKDAYS[wd]} ${date}`,
        person,
        subjects: periods.map((p) => p.subject),
        first_period: periods.find((p) => p.starts)?.starts?.slice(0, 5) ?? null,
      });
    }
  }

  const due: HandoverCard["money"]["due"] = [];
  for (const o of input.obligations) {
    const d = Number(o.due_day);
    if (!Number.isInteger(d) || d < 1 || d > 31) continue;
    const date = dates.find((x) => Number(x.slice(8, 10)) === d);
    if (date) due.push({ title: o.title, amount: o.amount, day: date });
  }

  return {
    days, from, to,
    ambulance: AMBULANCE_NUMBERS[String(input.country ?? "").trim().toUpperCase()] ?? null,
    doses, running_low, appointments, school,
    money: {
      per_day: input.budget?.daily_allowance_left ?? null,
      available: input.budget?.available ?? null,
      currency: input.currency,
      due: due.sort((a, b) => a.day.localeCompare(b.day)),
    },
    shopping: input.shopping.slice(0, 10),
  };
}

/** رحلة بدأت آخر ٤٨ ساعة وفي البيت حد تاني ⇒ زاد يعرض الكارت مرة للرحلة دي. */
export function handoverNoteFor(travelSince: string | null, familyMembers: number | null, nowMs: number):
  { subject: string; detail: string } | null {
  if (!travelSince || (familyMembers ?? 0) < 2) return null;
  const t = Date.parse(travelSince);
  if (!Number.isFinite(t) || nowMs - t > 2 * DAY || t > nowMs) return null;
  return {
    subject: `كارت تسليم للرحلة — ${travelSince.slice(0, 10)}`,
    detail: "العميل مسافر واللي في البيت هيمسك الأدوية والمواعيد والمدارس والمصروف. اعرض عليه مرة: «أجهزلك كارت تسليم للي في البيت؟» — " +
      "ولو وافق نادِ handover_card بعدد أيام الرحلة. الكارت من بياناته هو بس، من غير أي موقع.",
  };
}
