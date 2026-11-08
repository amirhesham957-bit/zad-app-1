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
 * كيانات person فيها أحياناً العميل نفسه والمساعد (اتقاس ٨/١١ على حساب المالك: «العميل» و«زاد» و«ميرو»)، فخرج
 * «عيد ميلاد زاد امتى؟». دول مش ناس بيتسأل عن عيد ميلادهم.
 */
const NOT_PEOPLE = new Set(["العميل", "العميله", "زاد", "زادو", "انا", "نفسي", "انت", "انتي"]);
function nameKey(name: string): string {
  return name.trim().replace(/[أإآ]/g, "ا").replace(/ة/g, "ه").replace(/ى/g, "ي").replace(/\s+/g, " ").toLowerCase();
}
function notAnotherPerson(name: string, selfNames: readonly string[]): boolean {
  const key = nameKey(name);
  return NOT_PEOPLE.has(key) || selfNames.some((s) => s.trim().length > 0 && nameKey(s) === key);
}

const MONTH_WORDS: ReadonlyArray<readonly [string, number]> = [
  ["يناير", 1], ["فبراير", 2], ["مارس", 3], ["ابريل", 4], ["مايو", 5], ["يونيو", 6], ["يوليو", 7],
  ["اغسطس", 8], ["سبتمبر", 9], ["اكتوبر", 10], ["نوفمبر", 11], ["ديسمبر", 12],
];
const MONTH_ALT = MONTH_WORDS.map(([w]) => w).join("|");
const monthOf = (word: string) => MONTH_WORDS.find(([w]) => w === word)?.[1] ?? 0;

function plainText(text: string): string {
  return text.replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660)).replace(/[أإآ]/g, "ا");
}

/**
 * جواب قصير على «عيد ميلادك امتى؟»: «19-8»، «١٩/٨/١٩٩٠»، «١٩ أغسطس»، «أغسطس ١٩». السطر الأخير بس، لأن رسالة البوت
 * ممكن تيجي ملفوفة بسؤال معلّق فوقها. يوم-شهر (زي مصر والخليج)، إلا لو الأول مايبقاش يوم غير لو اتبدلوا. null = مش تاريخ.
 */
export function parseOccasionAnswer(text: string): { month: number; day: number } | null {
  const line = plainText(String(text ?? "")).split("\n").map((l) => l.trim()).filter(Boolean).pop() ?? "";
  if (line.length > 24) return null;
  const bare = line.replace(/^(يوم|في|مواليد)\s+/, "");
  const numeric = /^(\d{1,2})\s*[-/.]\s*(\d{1,2})(?:\s*[-/.]\s*\d{2,4})?$/.exec(bare);
  if (numeric) {
    const a = Number(numeric[1]), b = Number(numeric[2]);
    return checked(b > 12 && a <= 12 ? a : b, b > 12 && a <= 12 ? b : a);
  }
  const dayFirst = new RegExp(`^(\\d{1,2})\\s+(${MONTH_ALT})(?:\\s+\\d{4})?$`).exec(bare);
  if (dayFirst) return checked(monthOf(dayFirst[2]), Number(dayFirst[1]));
  const monthFirst = new RegExp(`^(${MONTH_ALT})\\s+(\\d{1,2})$`).exec(bare);
  return monthFirst ? checked(monthOf(monthFirst[1]), Number(monthFirst[2])) : null;
}
function checked(month: number, day: number): { month: number; day: number } | null {
  return occasionMd(month, day) ? { month, day } : null;
}

/**
 * ملاحظة عادية فيها عيد ميلاد («عيد ميلاد العميل يوم ١٩ أغسطس»): التأمل الليلي بيكتبها كده من غير خانة المناسبة،
 * فالسؤال كان بيفضل شايفه ناقص (بلاغ المالك ٨/١١). for = null ⇒ العميل نفسه. null = مش عيد ميلاد بتاريخ.
 */
export function occasionFromNote(
  note: string, selfNames: readonly string[] = [],
): { for: string | null; md: string } | null {
  const m = new RegExp(`عيد ميلاد(ي)?\\s*([^:\\d]*?)\\s*(?::|\\s)\\s*(?:يوم\\s+)?(\\d{1,2})\\s+(${MONTH_ALT})`).exec(plainText(String(note ?? "")));
  if (!m) return null;
  const md = occasionMd(monthOf(m[4]), Number(m[3]));
  if (!md) return null;
  const person = m[2].replace(/\s+يوم$/, "").trim();
  return { for: m[1] || !person || notAnotherPerson(person, selfNames) ? null : person.slice(0, 60), md };
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
  /** askedLedger.ts: اللي اتسأل عنه ومارديش مايتسألش عنه كل يوم. */
  mayAsk: (person: string | null) => boolean = () => true,
  /** اسم العميل زي ما بيتنادى: مش «شخص تاني» له عيد ميلاد تاني. */
  selfNames: readonly string[] = [],
): { for: string | null; question: string } | null {
  const known = new Set(
    rows.filter((r) => r.occasion === "birthday").map((r) => (r.occasion_for ?? "").trim().toLowerCase()),
  );
  const unknown: Array<string | null> = known.has("") ? [] : [null];
  const seen = new Set<string>();
  for (const raw of people) {
    const name = raw.trim();
    const key = name.toLowerCase();
    if (!name || known.has(key) || seen.has(key) || notAnotherPerson(name, selfNames)) continue;
    seen.add(key);
    unknown.push(name);
  }
  const candidates = unknown.filter(mayAsk).slice(0, 6);
  if (candidates.length === 0) return null;
  const day = Math.floor(Date.parse(`${localDate}T00:00:00Z`) / 86_400_000);
  const who = candidates[(Number.isFinite(day) ? day : 0) % candidates.length];
  return who === null
    ? { for: null, question: "عيد ميلادك امتى؟ عشان أفتكره وأفرح معاك يومها 🎂" }
    : { for: who, question: `عيد ميلاد ${who} امتى؟ عشان أفكّرك قبلها` };
}
