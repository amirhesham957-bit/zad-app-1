// appointmentsQuery.ts — العقل بيسأل جدول المواعيد نفسه (ZAD_PLAN ٨ج.٣).
//
// الـsnapshot فيه المواعيد الجاية لـ١٤ يوم و٣٠ صف بس، فـ«عندي إيه يوم ١٥؟» أو «إمتى ميعاد الدكتور؟» لميعاد بعد
// أسبوعين كان الموديل يجاوب عليهم بـ«مفيش» وهو مش شايف. find_appointments بتقرا من zad_appointments، والحساب هنا:
// المتكرر بيتفرد على الأيام بالساعة المحلية بنفس قواعد scheduleGuard.ts (يومي ⇒ كل يوم، أسبوعي ⇒ نفس اليوم في
// الأسبوع، شهري ⇒ نفس اليوم في الشهر — من أول ما يبدأ)، لأن الصف المتكرر فيه مرته الجاية بس.

export const MAX_AGENDA_DAYS = 62;

export interface AppointmentRow {
  id: string;
  title: string;
  kind?: string | null;
  starts_at: string;
  place_label?: string | null;
  remind_minutes_before?: number | null;
  recurrence?: string | null;
  for_person?: string | null;
  expected_cost?: number | null;
  status?: string | null;
}

export interface AgendaItem {
  id: string;
  date: string;
  time: string;
  title: string;
  kind: string | null;
  place: string | null;
  for_person: string | null;
  recurrence: string;
  remind_minutes_before: number | null;
  expected_cost: number | null;
  status: string;
}

interface Local { date: string; time: string; weekday: number; day: number }

function local(ms: number, timeZone: string): Local {
  const p: Record<string, string> = {};
  for (
    const x of new Intl.DateTimeFormat("en-US", {
      timeZone, year: "numeric", month: "2-digit", day: "2-digit", weekday: "short", hour: "2-digit", minute: "2-digit",
      hourCycle: "h23",
    }).formatToParts(new Date(ms))
  ) p[x.type] = x.value;
  return {
    date: `${p.year}-${p.month}-${p.day}`,
    time: `${p.hour === "24" ? "00" : p.hour}:${p.minute}`,
    weekday: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].indexOf(p.weekday),
    day: +p.day,
  };
}

/** YYYY-MM-DD صحيح؟ */
export function isLocalDate(s: unknown): s is string {
  return typeof s === "string" && /^\d{4}-\d{2}-\d{2}$/.test(s) && !Number.isNaN(Date.parse(`${s}T00:00:00Z`));
}

/** الأيام من [from] لـ[to] شاملين. */
export function daysBetween(from: string, to: string): string[] {
  const out: string[] = [];
  for (let t = Date.parse(`${from}T00:00:00Z`); t <= Date.parse(`${to}T00:00:00Z`); t += 86_400_000) {
    out.push(new Date(t).toISOString().slice(0, 10));
  }
  return out;
}

function item(r: AppointmentRow, date: string, time: string): AgendaItem {
  return {
    id: r.id, date, time, title: r.title, kind: r.kind ?? null, place: r.place_label ?? null,
    for_person: r.for_person ?? null, recurrence: r.recurrence ?? "once",
    remind_minutes_before: r.remind_minutes_before ?? null, expected_cost: r.expected_cost ?? null,
    status: r.status ?? "upcoming",
  };
}

/**
 * مواعيد الأيام من [from] لـ[to] (بتوقيت الحساب)، مرتبة باليوم والساعة. المتكرر بيظهر في كل يوم بيقع فيه من أول
 * ما يبدأ؛ «كل ساعة» بيظهر مرة في اليوم بساعة أوله. الملغي والمخلص بيتشالوا إلا لو المرة الواحدة نفسها في اليوم.
 */
export function appointmentAgenda(
  rows: ReadonlyArray<AppointmentRow>, from: string, to: string, timeZone: string,
): AgendaItem[] {
  const days = daysBetween(from, to);
  const out: AgendaItem[] = [];
  for (const r of rows) {
    const at = Date.parse(r.starts_at);
    if (!Number.isFinite(at)) continue;
    const start = local(at, timeZone);
    const rec = r.recurrence ?? "once";
    if (rec === "once") {
      if (days.includes(start.date)) out.push(item(r, start.date, start.time));
      continue;
    }
    if ((r.status ?? "upcoming") !== "upcoming") continue;
    for (const d of days) {
      if (d < start.date) continue;
      const dt = new Date(`${d}T00:00:00Z`);
      const hit = rec === "daily" || rec === "hourly" ||
        (rec === "weekly" && dt.getUTCDay() === start.weekday) ||
        (rec === "monthly" && dt.getUTCDate() === start.day);
      if (hit) out.push(item(r, d, start.time));
    }
  }
  return out.sort((a, b) => (a.date + a.time).localeCompare(b.date + b.time));
}

function norm(s: string | null | undefined): string {
  return (s ?? "").trim().toLowerCase()
    .replace(/[أإآ]/g, "ا").replace(/ة/g, "ه").replace(/ى/g, "ي").replace(/[ًٌٍَُِّْـ]/g, "")
    .replace(/(^|\s)ال/g, "$1").replace(/\s+/g, " ");
}

/** كل كلمة في [query] (حرفين وأكتر) موجودة في الاسم أو المكان أو صاحب الميعاد؟ */
export function matchesAppointmentQuery(
  title: string, place: string | null | undefined, forPerson: string | null | undefined, query: string,
): boolean {
  const words = norm(query).split(" ").filter((w) => w.length >= 2);
  if (words.length === 0) return false;
  const hay = norm(`${title} ${place ?? ""} ${forPerson ?? ""}`);
  return words.every((w) => hay.includes(w));
}

/**
 * المواعيد اللي اسمها أو مكانها أو صاحبها فيه كلام [query] — كل كلمة لازم تلاقي نفسها («دكتور بابا» يلاقي
 * «دكتور القلب» لـبابا). كل صف بمرته الجاية (المتكرر اللي بدايته فاتت بيتقدّم لأقرب مرة بعد [nowMs]).
 */
export function searchAppointments(
  rows: ReadonlyArray<AppointmentRow>, query: string, timeZone: string, nowMs: number,
): AgendaItem[] {
  const today = local(nowMs, timeZone).date;
  return rows
    .filter((r) => matchesAppointmentQuery(r.title, r.place_label, r.for_person, query))
    .map((r) => {
      const at = Date.parse(r.starts_at);
      const start = local(at, timeZone);
      if ((r.recurrence ?? "once") === "once" || start.date >= today || (r.status ?? "upcoming") !== "upcoming") {
        return item(r, start.date, start.time);
      }
      const nowTime = local(nowMs, timeZone).time;
      const next = appointmentAgenda([r], today, addDays(today, 31), timeZone)
        .find((a) => a.date > today || a.time >= nowTime);
      return next ?? item(r, start.date, start.time);
    })
    .sort((a, b) => (a.date + a.time).localeCompare(b.date + b.time));
}

function addDays(date: string, n: number): string {
  return new Date(Date.parse(`${date}T00:00:00Z`) + n * 86_400_000).toISOString().slice(0, 10);
}
