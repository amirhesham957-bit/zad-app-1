// eventAhead.ts — القرارات الكبيرة بتتسأل في وقتها (ZAD_PLAN ٥.٦، الشريحة التانية).
//
// قبل الحدث الكبير بوقت كفاية، سؤال الصبح (نفس خانة عرض الهدية — سؤال واحد في اليوم) بيسأل: «رمضان بعد ١٤ يوم — تحب
// نحجز مبلغ ليه من دلوقتي؟». **من غير رقم مقترح**: مفيش تاريخ لرمضان اللي فات عند أغلب البيوت، والرقم المخترع أوحش من
// السؤال. جواب العميل بمبلغ ⇒ set_life_goal بعنوان الحدث وميعاده (زي الهدية)، فالمتاح بيتوزع والهدف بيتابع.
//
// إمتى (يوم واحد بالظبط بتوقيت السوق، فالسؤال بيتسأل مرة لكل حدث من غير جدول يفتكر):
//   - رمضان وذي الحجة: قبل أول يوم بـ١٤ يوم (أم القرى، `seasonFor`).
//   - رجوع المدارس: قبل بداية الشباك بـ١٤ يوم (`seasonal_event_windows`، نفس الحملة اللي على الرئيسية) — بيت فيه عيال
//     (`kids_count` > 0) وفي الخليج بس: الشباك المزروع ١٥ أغسطس، ومدارس مصر بتبدأ آخر سبتمبر، فسؤال مصري هنا هيبقى بدري
//     شهر ونص. لحد ما يبقى فيه شباك لكل سوق، مصر مابتتسألش.
//   - السفر: ميعاد مرة واحدة بكلمة سفر (`eventWeight` = ٢) بعد ٣ أيام.
// يوم الصبح فاته (ظرف، مفيش تحية) = السؤال بيتساب للحدث ده — مش بيتأجل.

import { eventWeight, TRAVEL_WEIGHT, type EventAppointment } from "./eventDayBudget.ts";
import { seasonFor } from "../_shared/season.ts";
import { seasonDueToday } from "../_shared/seasonCalendar.ts";

export const SEASON_ASK_DAYS = 14;
export const TRAVEL_ASK_DAYS = 3;
/** البلاد اللي شباك رجوع المدارس (١٥ أغسطس) قريب من بدايتها فعلاً. */
export const SCHOOL_WINDOW_MARKETS = new Set(["SA", "AE", "KW", "QA", "BH", "OM"]);

export type EventAheadKind = "ramadan" | "dhul_hijjah" | "back_to_school" | "travel" | "season";

export interface EventAhead {
  kind: EventAheadKind;
  /** عنوان الهدف لو العميل حجز («رمضان ١٤٤٨»، «سفر إسكندرية»). */
  title: string;
  /** يوم الحدث (YYYY-MM-DD بتوقيت السوق) = deadline الهدف. */
  on: string;
  in_days: number;
}

const DAY = 86_400_000;

function addDays(localDate: string, n: number): string {
  return new Date(Date.parse(`${localDate}T00:00:00Z`) + n * DAY).toISOString().slice(0, 10);
}

function localDay(ms: number, timeZone: string): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date(ms));
}

/** الحدث اللي النهارده يومه يتسأل عنه، أو null. الأقرب الأول (السفر)، وبعده المواسم. نقي. */
export function eventAhead(input: {
  localDate: string;
  timeZone: string;
  country: string | null | undefined;
  kidsCount: number | null | undefined;
  /** شبابيك المواسم العامة (slug + start_date). */
  seasonWindows: ReadonlyArray<{ slug: string; start_date: string }>;
  appointments: ReadonlyArray<EventAppointment>;
}): EventAhead | null {
  const travelDay = addDays(input.localDate, TRAVEL_ASK_DAYS);
  const trip = input.appointments.find((a) => {
    const at = Date.parse(a.starts_at ?? "");
    return Number.isFinite(at) && eventWeight(a) === TRAVEL_WEIGHT && localDay(at, input.timeZone) === travelDay;
  });
  if (trip) {
    const title = String(trip.title ?? "").trim().slice(0, 60) || "السفر";
    return { kind: "travel", title, on: travelDay, in_days: TRAVEL_ASK_DAYS };
  }

  const seasonDay = addDays(input.localDate, SEASON_ASK_DAYS);
  // الظهر بتوقيت UTC لليوم ده: بعيد عن حدود اليوم في أي منطقة من -١١ لـ+١١.
  const s = seasonFor(new Date(`${seasonDay}T12:00:00Z`), input.timeZone);
  if (s && s.hijri_day === 1 && (s.hijri_month === 9 || s.hijri_month === 12)) {
    return s.hijri_month === 9
      ? { kind: "ramadan", title: `رمضان ${s.hijri_year}`, on: seasonDay, in_days: SEASON_ASK_DAYS }
      : { kind: "dhul_hijjah", title: `عيد الأضحى ${s.hijri_year}`, on: seasonDay, in_days: SEASON_ASK_DAYS };
  }

  const country = String(input.country ?? "").trim().toUpperCase();
  if ((Number(input.kidsCount) || 0) > 0 && SCHOOL_WINDOW_MARKETS.has(country) &&
    input.seasonWindows.some((w) => w.slug === "back_to_school" && w.start_date === seasonDay)) {
    return { kind: "back_to_school", title: `مصاريف المدارس ${seasonDay.slice(0, 4)}`, on: seasonDay, in_days: SEASON_ASK_DAYS };
  }
  // ٧.٣: باقي مواسم بلده (seasonCalendar.ts).
  const due = seasonDueToday(country, input.localDate, Number(input.kidsCount) || 0);
  return due ? { kind: "season", title: `${due.name} ${due.on.slice(0, 4)}`, on: due.on, in_days: due.in_days } : null;
}

const ASK: Record<EventAheadKind, (e: EventAhead) => string> = {
  ramadan: (e) => `رمضان بعد ${e.in_days} يوم، والياميش والأساسيات أسعارها بتعلى قبله. تحب نحجز مبلغ ليه من دلوقتي؟ قولّي قد إيه.`,
  dhul_hijjah: (e) => `ذي الحجة بعد ${e.in_days} يوم والعيد بعدها بعشرة. هتضحّوا السنة دي؟ لو آه، نحجز مبلغ ليه من دلوقتي؟`,
  back_to_school: (e) => `المدارس بتبدأ بعد حوالي ${e.in_days} يوم (شنط، كتب، هدوم). تحب نحجز مبلغ ليها من دلوقتي؟ قولّي قد إيه.`,
  season: (e) => `${e.title.replace(/ \d{4}$/, "")} بعد ${e.in_days} يوم. تحب نحجز مبلغ ليه من دلوقتي؟ قولّي قد إيه، وهدوّر لك على العروض قبله.`,
  travel: (e) => `${e.title} بعد ${e.in_days} أيام. تحب نحجز مبلغ للسفر عشان باقي الأيام تتوزع صح؟ قولّي قد إيه.`,
};

/** سؤال الصبح. */
export function eventAheadQuestion(e: EventAhead): string {
  return ASK[e.kind](e);
}
