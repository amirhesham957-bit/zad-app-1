// occasions.ts — أعياد الميلاد وذكرى الجواز في ذاكرة العقل (20261006000000، قرار المالك 2026-10-05).
//
// المناسبة ملاحظة في zad_memory معاها occasion/occasion_md/occasion_for. هنا الحساب الصافي:
// الجملة اللي بتتكتب، كام يوم فاضل، مين عنده مناسبة النهارده أو بعد ٣ أيام، ومبلغ الهدية
// المقترح. صفر توكنز وصفر شبكة — تحية الصبح بتنادي ده، والتطبيق عنده نسخته (occasions.dart).

/** الأيام اللي تحية الصبح بتتكلم فيها عن مناسبة: يومها، وقبلها بـ٣ (وقت تجهيز هدية). */
export const OCCASION_HORIZONS: readonly number[] = [0, 3];

export type OccasionKind = "birthday" | "anniversary";

export interface OccasionRow {
  occasion: string;
  occasion_for: string | null;
  occasion_md: string;
}

export interface UpcomingOccasion {
  occasion: OccasionKind;
  /** null = العميل نفسه. */
  for: string | null;
  md: string;
  in_days: number;
}

const MONTHS_AR = [
  "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
  "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر",
];

const DAYS_IN_MONTH = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

/** شهر ويوم بيكوّنوا يوم حقيقي في سنة كبيسة (٢٩ فبراير مقبول) ⇒ 'MM-DD'، وإلا null. */
export function occasionMd(month: unknown, day: unknown): string | null {
  const m = Number(month);
  const d = Number(day);
  if (!Number.isInteger(m) || !Number.isInteger(d) || m < 1 || m > 12 || d < 1 || d > DAYS_IN_MONTH[m - 1]) {
    return null;
  }
  return `${String(m).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
}

/** «12 مارس». */
export function occasionDateLabel(md: string): string {
  const [m, d] = md.split("-").map(Number);
  return `${d} ${MONTHS_AR[m - 1]}`;
}

/** الجملة اللي بتتحفظ في الذاكرة — بتظهر في الشات وشاشة الذاكرة زي أي ملاحظة. */
export function occasionNote(kind: OccasionKind, person: string | null, md: string): string {
  const what = kind === "birthday" ? "عيد ميلاد" : "ذكرى جواز";
  return `${what} ${person ?? "العميل"}: ${occasionDateLabel(md)}`;
}

function isLeap(year: number): boolean {
  return (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0;
}

/**
 * كام يوم لحد المرة الجاية (٠ = النهارده). localDate = YYYY-MM-DD بتوقيت سوق الحساب.
 * ٢٩ فبراير في سنة بسيطة بيتحسب ٢٨ — المناسبة مابتختفيش ٣ سنين من ٤.
 */
export function daysUntilOccasion(md: string, localDate: string): number | null {
  const today = Date.parse(`${localDate}T00:00:00Z`);
  if (!Number.isFinite(today) || !/^\d{2}-\d{2}$/.test(md)) return null;
  const year = new Date(today).getUTCFullYear();
  const [m, d] = md.split("-").map(Number);
  const on = (y: number) => Date.UTC(y, m - 1, m === 2 && d === 29 && !isLeap(y) ? 28 : d);
  let next = on(year);
  if (next < today) next = on(year + 1);
  return Math.round((next - today) / 86_400_000);
}

/** المناسبات اللي يومها النهارده أو بعد ٣ أيام — الأقرب الأول، العميل نفسه قبل غيره، ٣ بالكتير. */
export function upcomingOccasions(rows: readonly OccasionRow[], localDate: string): UpcomingOccasion[] {
  const out: UpcomingOccasion[] = [];
  for (const r of rows) {
    if (r.occasion !== "birthday" && r.occasion !== "anniversary") continue;
    const inDays = daysUntilOccasion(r.occasion_md, localDate);
    if (inDays === null || !OCCASION_HORIZONS.includes(inDays)) continue;
    out.push({ occasion: r.occasion, for: r.occasion_for, md: r.occasion_md, in_days: inDays });
  }
  return out
    .sort((a, b) => a.in_days - b.in_days || Number(a.for !== null) - Number(b.for !== null))
    .slice(0, 3);
}

/**
 * مبلغ هدية يتحجز من المتاح: حوالي ٥٪ منه، مقرّب لرقم مستدير. متاح صفر أو بالسالب أو
 * مش معروف ⇒ null — مابنقترحش صرف على بيت مزنوق.
 */
export function giftSuggestion(available: unknown): number | null {
  const a = Number(available);
  if (!Number.isFinite(a) || a <= 0) return null;
  const raw = a * 0.05;
  const step = raw >= 1000 ? 100 : raw >= 200 ? 50 : 10;
  const amount = Math.round(raw / step) * step;
  return amount >= step ? amount : null;
}

/**
 * سؤال الصبح عن مناسبة ناقصة — العقل بيسأل بنفسه بدل ما يستنى العميل يقول (طلب المالك 2026-10-05:
 * «الأيجنت يسأل العميل في تليجرام لحد ما يجمع ده»). عيد ميلاد العميل الأول، وبعده الناس اللي
 * الذاكرة عارفاهم (كيانات person) ومالهمش عيد ميلاد متسجّل — واحد في اليوم، بيلف بالتاريخ.
 * الجواب بيرجع لفة شات عادية (askedThisMorning kind = occasion) وremember_occasion بيحفظه.
 */
export function occasionQuestion(
  rows: readonly OccasionRow[],
  people: readonly string[],
  localDate: string,
): { for: string | null; question: string } | null {
  const known = new Set(
    rows.filter((r) => r.occasion === "birthday").map((r) => (r.occasion_for ?? "").trim().toLowerCase()),
  );
  const candidates: Array<string | null> = known.has("") ? [] : [null];
  const seen = new Set<string>();
  for (const raw of people) {
    const name = raw.trim();
    const key = name.toLowerCase();
    if (!name || known.has(key) || seen.has(key)) continue;
    seen.add(key);
    candidates.push(name);
    if (candidates.length >= 6) break;
  }
  if (candidates.length === 0) return null;
  const day = Math.floor(Date.parse(`${localDate}T00:00:00Z`) / 86_400_000);
  const who = candidates[(Number.isFinite(day) ? day : 0) % candidates.length];
  return who === null
    ? { for: null, question: "عيد ميلادك امتى؟ عشان أفتكره وأفرح معاك يومها 🎂" }
    : { for: who, question: `عيد ميلاد ${who} امتى؟ عشان أفكّرك قبلها` };
}
