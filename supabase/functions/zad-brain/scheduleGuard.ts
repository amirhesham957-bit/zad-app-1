// scheduleGuard.ts — حارس التوقيت (ZAD_LIVING_BRAIN.md الشريحة ٤١).
//
// ميعاد جديد في نفس الوقت (أقل من ساعة) مع ميعاد تاني لنفس الشخص ⇒ زاد تنبّه فوراً وتسأل. **مابيرفضش ومابيلغيش**:
// اتنين في نفس الساعة ممكن يكونوا مقصودين («البنك وبعده الصيدلية جنبه»)، فالقرار للعميل.
// المواعيد مالهاش مدة، فالنافذة ساعة على الجانبين. المتكرر بيتقارن بالساعة المحلية: يومي ⇒ كل يوم، أسبوعي ⇒ نفس اليوم في
// الأسبوع، شهري ⇒ نفس اليوم في الشهر — من أول ما يبدأ. «كل ساعة» (اشرب مية) مابيتحسبش تعارض على الناحيتين.
// نفس المنطق في التطبيق (`appointmentClashes` في `features/appointments/domain/appointments.dart`).
//
// ٨ج.٥: الحارس بيشتغل **قبل** ما الميعاد يتحفظ مش بعده (`bookingConflicts`)، ومعاه تلات حاجات تانية من الـsnapshot:
// ساعات الشغل اللي في ملف العميل، دوا جوه نومه، وتذكير دوا فوق جرعة الصيدلية بتفكّره بيها أصلاً. فيه حاجة منهم ⇒
// الميعاد مابيتسجلش وزاد بتسأل سؤال واحد؛ العميل يأكد ⇒ نفس الأداة بـconfirm_conflict. برضه مابيرفضش: القرار للعميل.

export const CLASH_WINDOW_MINUTES = 60;

export interface ScheduledLike {
  id?: string | null;
  title?: string | null;
  starts_at?: string | null;
  recurrence?: string | null;
  for_person?: string | null;
  status?: string | null;
}

interface LocalParts { y: number; m: number; d: number; weekday: number; minute: number }

function localParts(ms: number, timeZone: string): LocalParts {
  const f = new Intl.DateTimeFormat("en-US", {
    timeZone, year: "numeric", month: "numeric", day: "numeric", weekday: "short", hour: "numeric", minute: "numeric",
    hourCycle: "h23",
  });
  const p: Record<string, string> = {};
  for (const x of f.formatToParts(new Date(ms))) p[x.type] = x.value;
  const weekday = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].indexOf(p.weekday);
  return { y: +p.year, m: +p.month, d: +p.day, weekday, minute: (+p.hour % 24) * 60 + +p.minute };
}

/** نفس الشخص: فاضي = العميل نفسه؛ غير كده بالاسم بعد القص وتوحيد الحروف. */
export function samePerson(a: string | null | undefined, b: string | null | undefined): boolean {
  const n = (s: string | null | undefined) =>
    (s ?? "").trim().replace(/\s+/g, " ").replace(/[أإآ]/g, "ا").replace(/ة/g, "ه").replace(/ى/g, "ي").toLowerCase();
  return n(a) === n(b);
}

/** الفرق بالدقايق بين ساعتين في اليوم، من غير ما نص الليل يفرّقهم (٢٣:٤٠ و٠٠:١٠ = ٣٠). */
function clockGap(a: number, b: number): number {
  const d = Math.abs(a - b);
  return Math.min(d, 1440 - d);
}

/** المواعيد اللي بتتعارض مع ميعاد جديد (أو متأجل — excludeId هو نفسه). */
export function scheduleClashes(input: {
  startsAt: string;
  forPerson?: string | null;
  recurrence?: string | null;
  existing: ReadonlyArray<ScheduledLike>;
  timeZone: string;
  excludeId?: string | null;
  windowMinutes?: number;
}): ScheduledLike[] {
  const window = input.windowMinutes ?? CLASH_WINDOW_MINUTES;
  const at = Date.parse(input.startsAt);
  if (!Number.isFinite(at) || input.recurrence === "hourly") return [];
  const mine = localParts(at, input.timeZone);
  return input.existing.filter((e) => {
    if (input.excludeId && e.id === input.excludeId) return false;
    if ((e.status ?? "upcoming") !== "upcoming") return false;
    const rec = e.recurrence ?? "once";
    if (rec === "hourly") return false;
    if (!samePerson(e.for_person, input.forPerson)) return false;
    const theirs = Date.parse(e.starts_at ?? "");
    if (!Number.isFinite(theirs)) return false;
    if (rec === "once") return Math.abs(theirs - at) < window * 60_000;
    // المتكرر: من أول ما بيبدأ بس.
    if (at < theirs - window * 60_000) return false;
    const p = localParts(theirs, input.timeZone);
    if (clockGap(p.minute, mine.minute) >= window) return false;
    if (rec === "daily") return true;
    if (rec === "weekly") return p.weekday === mine.weekday;
    if (rec === "monthly") return p.d === mine.d;
    return false;
  });
}

/** السطر اللي بيتضاف لنتيجة الأداة — العقل يقوله للعميل في جملة ويسأل. "" لو مفيش تعارض. */
export function clashNote(clashes: ReadonlyArray<ScheduledLike>, timeZone: string): string {
  if (clashes.length === 0) return "";
  const list = clashes.slice(0, 3).map((c) => {
    const when = new Date(c.starts_at ?? "").toLocaleString("ar-EG", {
      timeZone, weekday: "long", hour: "numeric", minute: "2-digit",
    });
    const rec = c.recurrence && c.recurrence !== "once" ? " (متكرر)" : "";
    return `«${c.title ?? "ميعاد"}» ${when}${rec}`;
  }).join("، ");
  return `\n⚠️ تعارض في التوقيت: في نفس الوقت تقريباً عنده ${list}. قول ده للعميل في جملة واحدة واسأله: يسيبهم كده ولا يأجّل واحد؟ ` +
    "ماتلغيش ولا تأجّل حاجة من غير ما يقول.";
}

// ── ٨ج.٥: المراجعة قبل الحجز ────────────────────────────────────────────────────────────────

/** حروف عربي موحّدة وأرقام لاتيني — نفس توحيد samePerson. */
function norm(s: string): string {
  return s.replace(/[٠-٩]/g, (d) => String("٠١٢٣٤٥٦٧٨٩".indexOf(d)))
    .replace(/[أإآ]/g, "ا").replace(/ة/g, "ه").replace(/ى/g, "ي").replace(/ـ/g, "").toLowerCase();
}

const WEEKDAYS: Array<[RegExp, number]> = [
  [/الاحد|الحد/, 0], [/الاتنين|الاثنين/, 1], [/الثلاثاء|الثلاث|التلات/, 2], [/الاربعاء|الاربع/, 3],
  [/الخميس/, 4], [/الجمعه/, 5], [/السبت/, 6],
];
const DAY_BODIES = "احد|حد|اتنين|اثنين|ثلاثاء|ثلاث|تلات|تلاتاء|اربعاء|اربع|خميس|جمعه|سبت";
const DAY_ALT = DAY_BODIES.split("|").map((b) => `ال${b}`).join("|");

function dayOf(word: string): number | null {
  for (const [re, d] of WEEKDAYS) if (re.test(word)) return d;
  return null;
}

function daysIn(text: string): number[] {
  return [...text.matchAll(new RegExp(DAY_ALT, "g"))].map((m) => dayOf(m[0])!).filter((d) => d != null);
}

const PM = /^(م|مساء|مساءا|المسا|المساء|العصر|المغرب|بالليل|الليل|pm)$/;
const AM = /^(ص|صباحا|الصبح|الصباح|بدري|am)$/;
const NOON = /^(الضهر|الظهر|ضهرا|ظهرا)$/;
const MARK = "ص|م|صباحا|الصبح|الصباح|بدري|مساء|مساءا|المسا|المساء|العصر|المغرب|بالليل|الليل|الضهر|الظهر|ضهرا|ظهرا|am|pm";
const RANGE = new RegExp(
  `(\\d{1,2})(?:[:.](\\d{2}))?\\s*(${MARK})?\\s*(?:-|–|الي|لحد|لغايه|حتي|to|till|ل)\\s*(\\d{1,2})(?:[:.](\\d{2}))?\\s*(${MARK})?(?![\\p{L}\\d])`,
  "u",
);

function hourWith(h: number, mark: string | undefined): number {
  if (mark && PM.test(mark)) return h < 12 ? h + 12 : h;
  if (mark && AM.test(mark)) return h === 12 ? 0 : h;
  if (mark && NOON.test(mark)) return h <= 5 ? h + 12 : h;
  return h;
}

export interface WorkHours {
  /** أيام الشغل (٠ = الأحد). */
  days: number[];
  /** بداية ونهاية الشفت بالدقايق من نص الليل؛ النهاية أصغر من البداية = شفت بيعدّي نص الليل. */
  start: number;
  end: number;
}

/**
 * ساعات الشغل من `customer_profile.work_schedule` — نص حر بكلام العميل («من ٩ لـ٥ غير الجمعة»، «الأحد للخميس ٨-٣»،
 * «من ١٠ بالليل لـ٦ الصبح»). من غير ساعتين واضحتين ⇒ null، والحارس مابيسألش: سؤال غلط أسوأ من سكوت.
 * الأيام: مدى («الأحد للخميس») أو قايمة، وناقص منهم اللي بعد «غير/ماعدا/إجازة»؛ مفيش أيام ⇒ كل الأسبوع غير الجمعة
 * (الإجازة المشتركة في مصر والسعودية).
 */
export function parseWorkSchedule(text: string | null | undefined): WorkHours | null {
  if (!text) return null;
  // «للخميس» = «لـ» + «الخميس» والألف بتقع.
  const t = norm(text).replace(/\s+/g, " ").replace(new RegExp(`لل(?=(?:${DAY_BODIES}))`, "g"), "ل ال");
  const m = RANGE.exec(t);
  if (!m) return null;
  let s = Number(m[1]), e = Number(m[4]);
  if (s > 24 || e > 24) return null;
  const sMark = m[3], eMark = m[6];
  if (!sMark && !eMark && s < 6) { // «من ٢ لـ١٠» من غير «بالليل» = بعد الضهر
    s += 12;
    if (e < 12) e += 12;
  }
  s = hourWith(s, sMark) % 24;
  e = hourWith(e, eMark);
  if (!eMark && e <= s && e < 12) e += 12; // «من ٩ لـ٥» = لحد ٥ العصر
  e %= 24;
  const start = s * 60 + Number(m[2] ?? 0), end = e * 60 + Number(m[5] ?? 0);
  if (start === end) return null;

  const cut = t.search(/غير|ماعدا|ما عدا|الا |اجاز|عطله|off/);
  const before = cut < 0 ? t : t.slice(0, cut), after = cut < 0 ? "" : t.slice(cut);
  let days: number[];
  const span = new RegExp(`(${DAY_ALT}) ?(?:-|–|الي|لحد|لغايه|حتي|ل) ?(${DAY_ALT})`).exec(before);
  if (span) {
    const a = dayOf(span[1])!, b = dayOf(span[2])!;
    days = [];
    for (let d = a; ; d = (d + 1) % 7) {
      days.push(d);
      if (d === b) break;
    }
  } else {
    const listed = daysIn(before);
    days = listed.length ? [...new Set(listed)] : cut < 0 ? [0, 1, 2, 3, 4, 6] : [0, 1, 2, 3, 4, 5, 6];
  }
  const off = new Set(daysIn(after));
  days = days.filter((d) => !off.has(d));
  return days.length ? { days, start, end } : null;
}

/** ساعة جوه مدى من غير ما نص الليل يقطعه ([a, b)). */
function within(min: number, a: number, b: number): boolean {
  return a <= b ? min >= a && min < b : min >= a || min < b;
}

/** في الشغل؟ الشفت اللي بيعدّي نص الليل بيتحسب على يوم ما بدأ. */
export function atWork(ms: number, w: WorkHours, timeZone: string): boolean {
  const p = localParts(ms, timeZone);
  if (w.start < w.end) return w.days.includes(p.weekday) && within(p.minute, w.start, w.end);
  if (p.minute >= w.start) return w.days.includes(p.weekday);
  if (p.minute < w.end) return w.days.includes((p.weekday + 6) % 7);
  return false;
}

/** تذكير بدوا من اسمه — «الكيند» مش مرجع: الـ١١ ميعاد الحيين كلهم personal (قياس ٢٠٢٦-١٠-٢٨). */
const MEDICINE_RE = /دوا|دواء|ادويه|علاج|حبايه|حبوب|حبه الضغط|حبه السكر|برشام|اقراص|قرص|كبسول|جرعه|ابره|حقنه|انسولين|قطره|بخاخ|فيتامين|مضاد|medicine|meds|pill|dose/;

export function isMedicineReminder(title: string | null | undefined): boolean {
  return MEDICINE_RE.test(norm(title ?? ""));
}

function hhmm(s: string): number | null {
  const m = /^(\d{1,2}):(\d{2})/.exec(s.trim());
  return m ? Number(m[1]) * 60 + Number(m[2]) : null;
}

/** بعد ما ينام بنص ساعة ولحد ما يصحى — «دوا قبل النوم» على ميعاد نومه مش تعارض. */
export const SLEEP_GRACE_MINUTES = 30;
/** تذكير دوا أقرب من كده لجرعة الصيدلية = نفس الجرعة. */
export const DOSE_TWIN_MINUTES = 30;

export interface BookingConflict { kind: "clash" | "work" | "sleep" | "dose"; text: string }

/**
 * التعارضات قبل الحجز. الشغل والنوم للعميل نفسه بس (`for_person` فاضي): الملف والنوم بتوعه، مش بتوع بابا ولا يوسف.
 * الشغل مابيتراجعش على ميعاد شغل، ولا تذكير يومي/كل ساعة (اشرب مية، الدوا)، ولا تذكير دوا — دول بيتعملوا وهو في الشغل.
 */
export function bookingConflicts(input: {
  title: string;
  startsAt: string;
  kind?: string | null;
  recurrence?: string | null;
  forPerson?: string | null;
  timeZone: string;
  existing: ReadonlyArray<ScheduledLike>;
  workSchedule?: string | null;
  sleep?: { bed?: string | null; wake?: string | null } | null;
  medicines?: ReadonlyArray<{ name?: string | null; for?: string | null; times?: string | null }>;
}): BookingConflict[] {
  const at = Date.parse(input.startsAt);
  if (!Number.isFinite(at)) return [];
  const rec = input.recurrence ?? "once";
  const self = !(input.forPerson ?? "").trim();
  const medicine = isMedicineReminder(input.title);
  const tz = input.timeZone;
  const minute = localParts(at, tz).minute;
  const clock = (min: number) => `${String(Math.floor(min / 60)).padStart(2, "0")}:${String(min % 60).padStart(2, "0")}`;
  const out: BookingConflict[] = [];

  const clashes = scheduleClashes({ startsAt: input.startsAt, forPerson: input.forPerson, recurrence: rec, existing: input.existing, timeZone: tz });
  if (clashes.length) {
    const list = clashes.slice(0, 3).map((c) => {
      const when = new Date(c.starts_at ?? "").toLocaleString("ar-EG", { timeZone: tz, weekday: "long", hour: "numeric", minute: "2-digit" });
      return `«${c.title ?? "ميعاد"}» ${when}${c.recurrence && c.recurrence !== "once" ? " (متكرر)" : ""}`;
    }).join("، ");
    out.push({ kind: "clash", text: `في نفس الوقت تقريباً عنده ${list}` });
  }

  const work = self && !medicine && input.kind !== "work" && rec !== "hourly" && rec !== "daily"
    ? parseWorkSchedule(input.workSchedule) : null;
  if (work && atWork(at, work, tz)) {
    out.push({ kind: "work", text: `الوقت ده جوه مواعيد شغله («${String(input.workSchedule).trim()}»)` });
  }

  const bed = hhmm(input.sleep?.bed ?? ""), wake = hhmm(input.sleep?.wake ?? "");
  if (self && medicine && rec !== "hourly" && bed != null && wake != null &&
    within(minute, (bed + SLEEP_GRACE_MINUTES) % 1440, wake)) {
    out.push({ kind: "sleep", text: `الدوا ده ${clock(minute)} وهو بيكون نايم (بينام ${clock(bed)} وبيصحى ${clock(wake)})` });
  }

  if (medicine && rec !== "hourly") {
    for (const m of input.medicines ?? []) {
      if (!samePerson(m.for, input.forPerson)) continue;
      const twin = (m.times ?? "").split(",").map(hhmm).find((d) => d != null && clockGap(d, minute) <= DOSE_TWIN_MINUTES);
      if (twin != null) {
        out.push({ kind: "dose", text: `الصيدلية بتفكّره أصلاً بـ«${m.name ?? "دوا"}» الساعة ${clock(twin)}` });
        break;
      }
    }
  }
  return out;
}

/** نتيجة الأداة لما فيه تعارض: الميعاد ماتسجلش، وسؤال واحد يجمع الأسباب كلها. */
export function bookingQuestion(conflicts: ReadonlyArray<BookingConflict>): string {
  return `مرفوض: لسه ماسجّلتش الميعاد — ${conflicts.map((c) => c.text).join("؛ ")}. ` +
    "اسأل العميل سؤال واحد بيجمع ده (يسجّله كده ولا وقت تاني؟). لو قال يسجّله زي ما هو ابعت نفس add_appointment بنفس القيم " +
    "ومعاها confirm_conflict=true؛ لو قال وقت تاني ابعت الوقت الجديد من غير confirm_conflict. ماتقولش إنه اتسجل.";
}
