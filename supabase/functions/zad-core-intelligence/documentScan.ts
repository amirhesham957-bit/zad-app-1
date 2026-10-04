// documentScan.ts — الروشتة وجدول الحصص من الكاميرا (ZAD_LIVING_BRAIN.md الشريحة ٢١).
//
// المالك (٢٠٢٦-١٠-٠٤): «بمجرد التقاط صورة لجدول حصص أو روشتة، العقل يستخرج المواعيد والبيانات ويحدث سجل
// الأولاد من غير إدخال يدوي» — واختارها أولوية. الكاميرا كانت بتقرا فاتورة ورف مخزن وعلبة دوا بس.
//
// القواعد (الروشتة بالذات — دي صحة):
//   - الموديل **بينقل اللي مكتوب بس**: اسم الدوا، التركيز، الطريقة زي ما هي، عدد المرات والمدة لو مكتوبين.
//     مكتوب بخط مش مقروء ⇒ legible = false والخانات فاضية — مفيش تخمين اسم دوا ولا جرعة.
//   - المواعيد المقترحة بتتحسب هنا من «كام مرة في اليوم» المكتوبة (مش من الموديل)، و«عند اللزوم» من غير مواعيد.
//   - التطبيق بيعرض كل سطر قابل للتعديل والعميل هو اللي يأكد — مفيش حاجة بتتكتب من الصورة لوحدها.

export type DocumentKind = "prescription" | "timetable";

export const PRESCRIPTION_PROMPT =
  "You read a doctor's prescription photographed by a family in Egypt or the Gulf for a household app (ZAD). " +
  "TRANSCRIBE ONLY what is written — never add a medicine, a strength, a frequency or a duration that is not on the paper. " +
  "Handwriting you cannot read with confidence: set \"legible\": false and leave the unclear fields null — do not guess a drug name. " +
  "For each medicine line: `name` as written (brand or generic, Latin or Arabic), `strength` (e.g. '500 mg', '5 ml') or null, " +
  "`form` in Arabic (قرص، كبسولة، شراب، نقط، حقنة، كريم، مرهم، بخاخ، لبوس، أكياس) or null, `instructions` = the directions exactly as written " +
  "(Arabic or Latin, e.g. 'قرص كل ٨ ساعات بعد الأكل', '1x3', 'tds pc'), `times_per_day` = integer ONLY if the paper states it " +
  "(1x3 / tds / tid / 3 مرات / كل ٨ ساعات → 3; bid / 2 مرات / كل ١٢ ساعة → 2; od / مرة / يومياً → 1; qid → 4), else null, " +
  "`duration_days` integer ONLY if written ('لمدة ٥ أيام', 'x 7 days', 'أسبوع' → 7), else null, `as_needed` true for 'عند اللزوم' / prn / sos. " +
  "Also `patient_name` and `doctor` if printed, and `date` as YYYY-MM-DD if written, else null. " +
  "Return ONLY JSON: {\"patient_name\":null,\"doctor\":null,\"date\":null,\"medicines\":[{\"name\":\"\",\"strength\":null,\"form\":null," +
  "\"instructions\":\"\",\"times_per_day\":null,\"duration_days\":null,\"as_needed\":false,\"legible\":true}]}";

export const TIMETABLE_PROMPT =
  "You read a school class timetable photographed by a parent for a household app (ZAD). Timetables are usually Arabic grids: " +
  "days as rows or columns (الأحد الإثنين الثلاثاء الأربعاء الخميس، أحياناً السبت)، periods (الحصة الأولى…) with optional times. " +
  "TRANSCRIBE ONLY what is written. For each school day: `day` = the day name as written, and `periods` in order: `order` (1 = first), " +
  "`start` and `end` as HH:MM 24-hour ONLY if printed (else null), `subject` exactly as written (e.g. 'رياضيات', 'لغة عربية', 'Science'). " +
  "Skip empty cells and breaks (فسحة / استراحة). Also `student_name` and `class_name` if printed, else null. " +
  "Return ONLY JSON: {\"student_name\":null,\"class_name\":null,\"days\":[{\"day\":\"الأحد\",\"periods\":[{\"order\":1,\"start\":null,\"end\":null,\"subject\":\"\"}]}]}";

const text = (v: unknown, max: number): string | null => {
  if (typeof v !== "string") return null;
  const t = v.replace(/[\u0000-\u001f\u007f]/g, " ").replace(/\s+/g, " ").trim();
  return t ? t.slice(0, max) : null;
};

const intIn = (v: unknown, min: number, max: number): number | null => {
  const n = typeof v === "number" ? v : typeof v === "string" ? Number(v.replace(/[٠-٩]/g, (d) => String("٠١٢٣٤٥٦٧٨٩".indexOf(d)))) : NaN;
  return Number.isInteger(n) && n >= min && n <= max ? n : null;
};

/** مواعيد مقترحة من «كام مرة في اليوم» — نفس صيغة zad_pharmacy_items.dose_times. ٥ مرات أو أكتر: العميل يحددها. */
export function doseTimesFor(timesPerDay: number | null, asNeeded: boolean): string | null {
  if (asNeeded || !timesPerDay) return null;
  switch (timesPerDay) {
    case 1: return "09:00";
    case 2: return "09:00,21:00";
    case 3: return "08:00,14:00,20:00";
    case 4: return "08:00,12:00,16:00,20:00";
    default: return null;
  }
}

export interface PrescriptionLine {
  name: string;
  strength: string | null;
  form: string | null;
  instructions: string | null;
  times_per_day: number | null;
  duration_days: number | null;
  as_needed: boolean;
  legible: boolean;
  suggested_times: string | null;
  /** جرعات الكورس كله لو المرات والمدة مكتوبين (المخزون يخلص مع الكورس)، وإلا null. */
  course_doses: number | null;
}

export interface Prescription {
  kind: "prescription";
  patient_name: string | null;
  doctor: string | null;
  date: string | null;
  medicines: PrescriptionLine[];
}

export function normalizePrescription(raw: unknown): Prescription {
  const r = (raw && typeof raw === "object" ? raw : {}) as Record<string, unknown>;
  const list = Array.isArray(r.medicines) ? r.medicines : [];
  const medicines: PrescriptionLine[] = [];
  for (const m of list.slice(0, 12) as Array<Record<string, unknown>>) {
    const name = text(m?.name, 60);
    if (!name || name.length < 2) continue;
    const asNeeded = m?.as_needed === true;
    const legible = m?.legible !== false;
    const times = asNeeded ? null : intIn(m?.times_per_day, 1, 6);
    const days = intIn(m?.duration_days, 1, 365);
    medicines.push({
      name,
      strength: text(m?.strength, 30),
      form: text(m?.form, 20),
      instructions: text(m?.instructions, 120),
      times_per_day: times,
      duration_days: days,
      as_needed: asNeeded,
      legible,
      suggested_times: legible ? doseTimesFor(times, asNeeded) : null,
      course_doses: legible && times && days ? times * days : null,
    });
  }
  const date = text(r.date, 10);
  return {
    kind: "prescription",
    patient_name: text(r.patient_name, 40),
    doctor: text(r.doctor, 60),
    date: date && /^\d{4}-\d{2}-\d{2}$/.test(date) ? date : null,
    medicines,
  };
}

// 0 = الأحد (نفس Date.getUTCDay و`extract(dow …)` في Postgres).
const DAYS: ReadonlyArray<[RegExp, number]> = [
  [/^(ال)?[أا]?حد|^sun/i, 0],
  [/^(ال)?[إا]?ثنين|^(ال)?اتنين|^mon/i, 1],
  [/^(ال)?ثلاثاء|^(ال)?تلات|^tue/i, 2],
  [/^(ال)?[أا]ربع|^wed/i, 3],
  [/^(ال)?خميس|^thu/i, 4],
  [/^(ال)?جمع|^fri/i, 5],
  [/^(ال)?سبت|^sat/i, 6],
];

export function weekdayOf(day: unknown): number | null {
  const t = text(day, 20);
  if (!t) return null;
  const n = intIn(t, 0, 6);
  if (n !== null) return n;
  const found = DAYS.find(([re]) => re.test(t.replace(/\s/g, "")));
  return found ? found[1] : null;
}

const hhmm = (v: unknown): string | null => {
  const t = text(v, 8);
  if (!t) return null;
  const m = /^(\d{1,2})[:.](\d{2})$/.exec(t);
  if (!m) return null;
  const h = Number(m[1]), min = Number(m[2]);
  return h <= 23 && min <= 59 ? `${String(h).padStart(2, "0")}:${m[2]}` : null;
};

export interface TimetablePeriod { order: number; start: string | null; end: string | null; subject: string }
export interface Timetable {
  kind: "timetable";
  student_name: string | null;
  class_name: string | null;
  days: Array<{ weekday: number; periods: TimetablePeriod[] }>;
}

const BREAK = /^(فسحة|استراحة|راحة|break|recess)$/i;

export function normalizeTimetable(raw: unknown): Timetable {
  const r = (raw && typeof raw === "object" ? raw : {}) as Record<string, unknown>;
  const byDay = new Map<number, TimetablePeriod[]>();
  for (const d of (Array.isArray(r.days) ? r.days : []).slice(0, 7) as Array<Record<string, unknown>>) {
    const weekday = weekdayOf(d?.day);
    if (weekday === null || byDay.has(weekday)) continue;
    const periods: TimetablePeriod[] = [];
    for (const p of (Array.isArray(d?.periods) ? d.periods : []).slice(0, 12) as Array<Record<string, unknown>>) {
      const subject = text(p?.subject, 40);
      if (!subject || BREAK.test(subject)) continue;
      periods.push({ order: periods.length + 1, start: hhmm(p?.start), end: hhmm(p?.end), subject });
    }
    if (periods.length) byDay.set(weekday, periods);
  }
  return {
    kind: "timetable",
    student_name: text(r.student_name, 40),
    class_name: text(r.class_name, 40),
    days: [...byDay.entries()].sort((a, b) => a[0] - b[0]).map(([weekday, periods]) => ({ weekday, periods })),
  };
}
