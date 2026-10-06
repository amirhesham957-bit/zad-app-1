// replyCadence.ts — طول الرد حسب وقت العميل (ZAD_LIVING_BRAIN.md الشريحة ٤٤).
//
// الطلب: «اختصار الردود التلقائية عند الانشغال وتوسيعها عند التفرغ». الانشغال والتفرغ **من المواعيد والساعة بس** — نفس حدود
// «ضغط البيت» (الشريحة ١٢): مش من نبرته ولا سرعة كتابته ولا استخدامه للموبايل، ومش بيتقاله «إنت مشغول».
//   - brief: عنده ميعاد دلوقتي أو كمان شوية (ساعة قبل لحد ساعة ونص بعد)، أو يومه مزحوم (٣ مواعيد+، الشريحة ١٨)، أو ضغط البيت عالي.
//   - roomy: مسا (٦–١١ بالليل بتوقيت السوق)، ومفيش ميعاد في التلات ساعات الجايين، ومش يوم مزحوم ولا ضغط عالي.
//   - normal: غير كده.
// بيتطبق على الشات (قاعدة في البرومبت) وعلى لحظات اليوم (الإشعارات والصوت) — من غير ما يعدّي سقف `momentLimits`.

export type ReplyCadence = "brief" | "normal" | "roomy";

export interface CadenceAppointment {
  title?: string | null;
  starts_at?: string | null;
  status?: string | null;
  recurrence?: string | null;
}

export const BUSY_BEFORE_MINUTES = 90;
export const BUSY_AFTER_MINUTES = 60;
export const FREE_AHEAD_MINUTES = 180;
export const ROOMY_FROM_HOUR = 18;
export const ROOMY_UNTIL_HOUR = 23;
export const BUSY_DAY_COUNT = 3;

function localHour(ms: number, timeZone: string): number {
  return Number(new Intl.DateTimeFormat("en-US", { timeZone, hour: "numeric", hourCycle: "h23" }).format(new Date(ms))) % 24;
}

export function replyCadence(input: {
  appointments: ReadonlyArray<CadenceAppointment>;
  nowMs: number;
  timeZone: string;
  /** مواعيد النهارده (لو معروفة). */
  appointmentsToday?: number;
  householdLevel?: "high" | "normal" | "easy" | null;
}): { mode: ReplyCadence; reason: string } {
  const live = input.appointments.filter((a) =>
    (a.status ?? "upcoming") === "upcoming" && a.recurrence !== "hourly" && Number.isFinite(Date.parse(a.starts_at ?? ""))
  );
  const near = live.find((a) => {
    const d = (Date.parse(a.starts_at!) - input.nowMs) / 60_000;
    return d >= -BUSY_AFTER_MINUTES && d <= BUSY_BEFORE_MINUTES;
  });
  if (near) return { mode: "brief", reason: `عنده «${String(near.title ?? "ميعاد").trim()}» دلوقتي أو كمان شوية` };
  if ((input.appointmentsToday ?? 0) >= BUSY_DAY_COUNT) return { mode: "brief", reason: `النهارده فيه ${input.appointmentsToday} مواعيد` };
  if (input.householdLevel === "high") return { mode: "brief", reason: "ضغط البيت عالي" };
  const hour = localHour(input.nowMs, input.timeZone);
  const soon = live.some((a) => {
    const d = (Date.parse(a.starts_at!) - input.nowMs) / 60_000;
    return d > 0 && d <= FREE_AHEAD_MINUTES;
  });
  if (hour >= ROOMY_FROM_HOUR && hour < ROOMY_UNTIL_HOUR && !soon) {
    return { mode: "roomy", reason: "مسا ومفيش مواعيد قريبة" };
  }
  return { mode: "normal", reason: "" };
}

/** قاعدة الشات. "" لو normal. */
export function replyCadenceRule(snap: { reply_cadence?: { mode: ReplyCadence; reason: string } | null } | null | undefined): string {
  const c = snap?.reply_cadence;
  if (!c || c.mode === "normal") return "";
  return c.mode === "brief"
    ? `**reply_cadence = brief** (${c.reason}): ردودك قصيرة — جملتين بالكتير، المطلوب بس، من غير اقتراحات جانبية ولا أسئلة زيادة. ` +
      "التنفيذ والأرقام المهمة زي ما هم. ماتقولش له إنه مشغول."
    : `**reply_cadence = roomy** (${c.reason}): عنده وقت — لو الكلام يستاهل، ممكن تفصّل شوية: سبب أو فكرة زيادة واحدة مفيدة، ` +
      "لحد ٥–٦ جمل. من غير حشو ولا تكرار، ولو سؤاله بسيط فالرد بسيط برضه.";
}

/** سطر للحظة (إشعار/صوت). "" لو normal. سقف momentLimits زي ما هو. */
export function replyCadenceMomentLine(mode: ReplyCadence): string {
  if (mode === "brief") return "العميل عنده ميعاد دلوقتي أو يومه مزحوم: text سطر واحد قصير، وspeech جملة واحدة — الأهم بس.";
  if (mode === "roomy") return "العميل فاضي (مسا ومفيش مواعيد قريبة): ممكن text لحد ٣ جمل وspeech لحد ٤ بتفصيلة مفيدة زيادة واحدة — من غير حشو.";
  return "";
}
