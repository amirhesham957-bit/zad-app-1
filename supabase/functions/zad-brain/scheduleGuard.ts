// scheduleGuard.ts — حارس التوقيت (ZAD_LIVING_BRAIN.md الشريحة ٤١).
//
// ميعاد جديد في نفس الوقت (أقل من ساعة) مع ميعاد تاني لنفس الشخص ⇒ زاد تنبّه فوراً وتسأل. **مابيرفضش ومابيلغيش**:
// اتنين في نفس الساعة ممكن يكونوا مقصودين («البنك وبعده الصيدلية جنبه»)، فالقرار للعميل.
// المواعيد مالهاش مدة، فالنافذة ساعة على الجانبين. المتكرر بيتقارن بالساعة المحلية: يومي ⇒ كل يوم، أسبوعي ⇒ نفس اليوم في
// الأسبوع، شهري ⇒ نفس اليوم في الشهر — من أول ما يبدأ. «كل ساعة» (اشرب مية) مابيتحسبش تعارض على الناحيتين.
// نفس المنطق في التطبيق (`appointmentClashes` في `features/appointments/domain/appointments.dart`).

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
