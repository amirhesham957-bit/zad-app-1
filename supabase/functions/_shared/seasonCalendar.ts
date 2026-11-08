// تقويم المواسم لكل بلد (ZAD_PLAN ٧.٣): اليوم بتاريخه، واللي البيت بيجيبه ليه، وإزاي يوفّر قبله.
//
// محسوب مش جدول: المواسم الهجرية من أم القرى (season.ts)، وشم النسيم من حساب الفصح الشرقي، والجمعة البيضاء من تقويم
// نوفمبر، فمفيش سنة تخلص ومحدش زرعها. `seasonal_events` عن قصد مااتزودش: التطبيق بيقرا كل صفوفه من غير بلد
// (local_reminders وحصالة العيلة)، فصف «اليوم الوطني» كان هيوصل لبيت في مصر.
//
// بداية المدارس في مصر تقريبية (تالت سبت في سبتمبر، والوزارة بتعلن كل سنة)، ومكتوبة «حوالي» في الخطة. الخليج ماشي على
// شباك `seasonal_event_windows` زي ما هو.

import { seasonFor } from "./season.ts";

export type CalendarSeasonKey =
  | "ahlan_ramadan" | "eid_fitr" | "eid_adha" | "white_friday" | "founding_day" | "national_day"
  | "mothers_day" | "sham_nessim" | "back_to_school_eg";

export interface CalendarSeason {
  key: CalendarSeasonKey;
  name: string;
  /** YYYY-MM-DD. */
  on: string;
  /** أصناف بتدخل اختيار العروض قبله. فاضية = موسم تخفيضات من غير قايمة. */
  needs: readonly string[];
  /** إزاي يوفّر قبله. */
  saving: string;
  /** للبيوت اللي فيها عيال بس. */
  kids_only?: boolean;
  /** التاريخ تقريبي. */
  approx?: boolean;
}

export interface UpcomingCalendarSeason extends CalendarSeason {
  in_days: number;
}

export const SEASON_PLAN_DAYS = 14;
/** أهلاً رمضان بيبدأ قبل رمضان بالأيام دي: أكبر عروض السلع الأساسية في السنة. */
export const AHLAN_RAMADAN_LEAD_DAYS = 21;

const DAY = 86_400_000;
const GULF = new Set(["SA", "AE", "KW", "QA", "BH", "OM"]);

const NATIONAL_DAYS: Readonly<Record<string, { name: string; md: string }>> = {
  SA: { name: "اليوم الوطني", md: "09-23" },
  AE: { name: "عيد الاتحاد", md: "12-02" },
  KW: { name: "العيد الوطني", md: "02-25" },
  QA: { name: "اليوم الوطني", md: "12-18" },
  BH: { name: "العيد الوطني", md: "12-16" },
};

const iso = (ms: number) => new Date(ms).toISOString().slice(0, 10);
const utc = (y: number, m: number, d: number) => Date.UTC(y, m - 1, d);

/** الجمعة بعد رابع خميس في نوفمبر. */
export function whiteFriday(year: number): string {
  const first = new Date(utc(year, 11, 1)).getUTCDay();
  const firstThursday = 1 + ((4 - first + 7) % 7);
  return iso(utc(year, 11, firstThursday + 22));
}

/** الاتنين بعد الفصح الشرقي (حساب ميوس لليولياني + فرق التقويم). */
export function shamNessim(year: number): string {
  const a = year % 4, b = year % 7, c = year % 19;
  const d = (19 * c + 15) % 30;
  const e = (2 * a + 4 * b - d + 34) % 7;
  const month = Math.floor((d + e + 114) / 31);
  const day = ((d + e + 114) % 31) + 1;
  return iso(utc(year, month, day) + 13 * DAY + DAY);
}

/** تالت سبت في سبتمبر. */
function egyptSchoolStart(year: number): string {
  const first = new Date(utc(year, 9, 1)).getUTCDay();
  return iso(utc(year, 9, 1 + ((6 - first + 7) % 7) + 14));
}

/** أيام السنة الميلادية اللي بتوافق أول رمضان وأول شوال وعاشر ذي الحجة. */
function hijriAnchors(year: number): Array<{ month: number; on: number }> {
  const out: Array<{ month: number; on: number }> = [];
  for (let t = utc(year, 1, 1); t < utc(year + 1, 1, 1); t += DAY) {
    const s = seasonFor(new Date(t + DAY / 2), "UTC");
    if (!s) continue;
    if ((s.hijri_month === 9 || s.hijri_month === 10) && s.hijri_day === 1) out.push({ month: s.hijri_month, on: t });
    if (s.hijri_month === 12 && s.hijri_day === 10) out.push({ month: 12, on: t });
  }
  return out;
}

export function seasonsOfYear(country: string, year: number): CalendarSeason[] {
  const code = country.trim().toUpperCase();
  const out: CalendarSeason[] = [];
  for (const { month, on } of hijriAnchors(year)) {
    if (month === 9) {
      out.push({
        key: "ahlan_ramadan", name: "أهلاً رمضان", on: iso(on - AHLAN_RAMADAN_LEAD_DAYS * DAY),
        needs: ["تمر", "ياميش", "قمر الدين", "زيت", "سكر", "رز", "مكرونة"],
        saving: "اشتري الأساسيات اللي بتتخزن من أول عروضها، قبل ما الأسعار تعلى في أول رمضان.",
      });
    } else if (month === 10) {
      out.push({
        key: "eid_fitr", name: "عيد الفطر", on: iso(on), needs: ["هدوم عيد", "كحك", "بسكويت"],
        saving: "حدد مبلغ العيدية والهدوم من دلوقتي، والكحك أرخص لو اتعمل أو اتحجز بدري.",
      });
    } else {
      out.push({
        key: "eid_adha", name: "عيد الأضحى", on: iso(on), needs: ["لحمة", "فريزر أكياس"],
        saving: "الأضحية بتغلى كل ما العيد يقرب: الحجز بدري أرخص، ولو مش هتضحّي قارن سعر اللحمة قبلها بأسبوعين.",
      });
    }
  }
  out.push({
    key: "white_friday", name: GULF.has(code) || code === "EG" ? "الجمعة البيضاء" : "بلاك فرايداي", on: whiteFriday(year), needs: [],
    saving: "اكتب اللي عايزه من دلوقتي وراقب سعره، عشان تعرف الخصم حقيقي ولا السعر اتعلّى قبله.",
  });
  const national = NATIONAL_DAYS[code];
  if (national) {
    out.push({
      key: "national_day", name: national.name, on: `${year}-${national.md}`, needs: [],
      saving: "تخفيضات اليوم ده بتتركز على الإلكترونيات والموضة: قارن السعر قبلها بأسبوع.",
    });
  }
  if (code === "SA") {
    out.push({
      key: "founding_day", name: "يوم التأسيس", on: `${year}-02-22`, needs: [],
      saving: "عروض اليوم ده بتبدأ قبله بكام يوم: اللي مستنيه راقب سعره من دلوقتي.",
    });
  }
  if (code === "EG") {
    out.push({
      key: "mothers_day", name: "عيد الأم", on: `${year}-03-21`, needs: [],
      saving: "حدد مبلغ الهدية من دلوقتي، وقارن قبل الأسبوع الأخير لما العروض تكتر.",
    });
    out.push({
      key: "sham_nessim", name: "شم النسيم", on: shamNessim(year), needs: ["فسيخ", "رنجة", "بصل أخضر", "بيض"],
      saving: "الرنجة والفسيخ بيغلوا آخر أسبوع: الشرا قبله بكام يوم أرخص.",
    });
    out.push({
      key: "back_to_school_eg", name: "رجوع المدارس", on: egyptSchoolStart(year), kids_only: true, approx: true,
      needs: ["شنطة مدرسة", "أدوات مدرسية", "كراسات", "زي مدرسي"],
      saving: "قسّم المصاريف: الزي والشنط بدري، والكراسات بعد ما القايمة تطلع.",
    });
  }
  return out;
}

/** المواسم اللي جاية جوه [horizonDays] من [localDate]، الأقرب الأول. النهارده نفسه داخل. */
export function upcomingCalendarSeasons(
  country: string | null | undefined,
  localDate: string,
  horizonDays = SEASON_PLAN_DAYS,
  kidsCount = 0,
): UpcomingCalendarSeason[] {
  const code = String(country ?? "").trim().toUpperCase();
  const today = Date.parse(`${localDate}T00:00:00Z`);
  if (!/^[A-Z]{2}$/.test(code) || !Number.isFinite(today)) return [];
  const year = new Date(today).getUTCFullYear();
  const out: UpcomingCalendarSeason[] = [];
  for (const s of [...seasonsOfYear(code, year), ...seasonsOfYear(code, year + 1)]) {
    const inDays = Math.round((Date.parse(`${s.on}T00:00:00Z`) - today) / DAY);
    if (inDays < 0 || inDays > horizonDays || (s.kids_only && kidsCount <= 0)) continue;
    out.push({ ...s, in_days: inDays });
  }
  return out.sort((a, b) => a.in_days - b.in_days);
}

/** مواسم سؤال الصبح: رمضان وذي الحجة ليهم سؤالهم في eventAhead، فمش هنا. أهلاً رمضان مش حدث فلوس لوحده. */
const ASK_KEYS: ReadonlySet<CalendarSeasonKey> = new Set([
  "eid_fitr", "white_friday", "founding_day", "national_day", "mothers_day", "sham_nessim", "back_to_school_eg",
]);

/** الموسم اللي النهارده بالظبط قبله بأسبوعين: يوم واحد لكل موسم، فمفيش جدول يفتكر إنه اتسأل. */
export function seasonDueToday(country: string | null | undefined, localDate: string, kidsCount = 0): UpcomingCalendarSeason | null {
  return upcomingCalendarSeasons(country, localDate, SEASON_PLAN_DAYS, kidsCount)
    .find((s) => s.in_days === SEASON_PLAN_DAYS && ASK_KEYS.has(s.key)) ?? null;
}

/** الخطة للموديل: سطر لكل موسم. النص ده مننا مش من العميل. */
export function seasonPlanInstruction(seasons: readonly UpcomingCalendarSeason[]): string {
  if (seasons.length === 0) return "";
  return "مواسم جاية (لو جه سياقها، اقترح خطة شرا وتوفير من غير ضغط، ومن غير افتراض إنه بيحتفل بيها): " + seasons.map((s) =>
    `${s.name} بعد ${s.approx ? "حوالي " : ""}${s.in_days} يوم${s.needs.length ? ` (${s.needs.join("، ")})` : ""}: ${s.saving}`
  ).join(" | ");
}
