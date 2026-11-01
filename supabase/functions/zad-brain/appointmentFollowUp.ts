// appointmentFollowUp.ts — «روحت الدكتور امبارح؟ قالك إيه؟» (ZAD_PLAN ٨ج.٦، الشريحة الأولى).
//
// المالك (٢٨/١٠): بعد الميعاد العقل يسأل ويحفظ الرد — من خلال المنسّق الواحد، مش قناة رسايل
// جديدة. فالسؤال بياخد خانة «سؤال كل يوم» في تحية الصبح زي الفضول (curiosity.ts): سؤال واحد في
// اليوم، والجواب بيرجع لفة شات عادية والعقل بيعرف هو جواب على إيه من asked_this_morning.
//
// - مين يتسأل عنه: ميعاد مرة واحدة كان امبارح بتوقيت بلد الحساب، مااتلغاش، ونوعه زيارة (طبي، أو
//   عنوانه فيه دكتور/مقابلة/مصلحة…). منبهات الصحيان والدوا والمتكرر مش زيارات — «صحيت امبارح؟»
//   سؤال مالوش لازمة.
// - مرة واحدة لكل ميعاد: facts.appointment_follow_up.id في تحيات الصبح آخر ٣٠ يوم — مفيش جدول جديد.
// - الجواب مابيتكتبش هنا: العقل بيسجّله بـremember في اللفة، ولو مارحش بيعرض يحجز تاني.

const DAY_MS = 86_400_000;

/** نفس الميعاد مابيتسألش عنه تاني (التحيات اللي بنبص فيها). */
export const ASKED_LOOKBACK_DAYS = 30;

/** كلمات في العنوان بتقول إن الميعاد زيارة ليها نتيجة تتسأل عنها. */
const VISIT_WORDS =
  /دكتور|دكتورة|د\.|عياد|مستشف|تحليل|تحاليل|أشع|اشع|سونار|كشف|متابعة|جلسة|علاج طبيعي|أسنان|اسنان|مقابل|انترفيو|إنترفيو|محكم|محامي|سفار|قنصلي|مصلح|جوازات|شهر عقاري|سجل مدني|مرور|بنك|مدرس|اجتماع أولياء|doctor|clinic|hospital|dentist|interview|embassy|court/i;

/** عناوين مش زيارات حتى لو نوعها طبي: منبه، دوا، رياضة. */
const NOT_A_VISIT = /صحّ?ي|صحيان|اصحى|منبه|منبّه|دوا|دواء|علاج$|حباية|برشام|قرص|wake|alarm|pill|medicine/i;

export interface FollowUpAppointment {
  id: string;
  title: string;
  kind: string | null;
  starts_at: string;
  recurrence: string | null;
  status: string | null;
}

export interface AppointmentFollowUp {
  id: string;
  title: string;
  kind: string;
  /** يوم الميعاد بتوقيت الحساب، YYYY-MM-DD. */
  on: string;
  question: string;
}

/** زيارة ليها نتيجة؟ */
export function isVisit(a: Pick<FollowUpAppointment, "title" | "kind">): boolean {
  const title = (a.title ?? "").trim();
  if (title === "" || NOT_A_VISIT.test(title)) return false;
  return a.kind === "medical" || VISIT_WORDS.test(title);
}

/** السؤال: الطبي «قالك إيه؟»، والباقي «عدّى إزاي؟». العقل بيصيغه بلهجة العميل. */
export function followUpQuestion(a: Pick<FollowUpAppointment, "title" | "kind">): string {
  const title = a.title.trim();
  const medical = a.kind === "medical" || /دكتور|دكتورة|عياد|مستشف|أسنان|اسنان|كشف|doctor|clinic|dentist/i.test(title);
  return medical ? `روحت ${title} امبارح؟ قالك إيه؟` : `${title} امبارح عدّى إزاي؟`;
}

/** مفاتيح المواعيد اللي اتسأل عنها في تحيات الصبح (facts.appointment_follow_up.id). */
export function askedFollowUpIds(rows: ReadonlyArray<{ facts?: unknown }> | null | undefined): Set<string> {
  const ids = new Set<string>();
  for (const r of rows ?? []) {
    const f = (r?.facts ?? {}) as { appointment_follow_up?: { id?: unknown } };
    const id = f.appointment_follow_up?.id;
    if (typeof id === "string" && id !== "") ids.add(id);
  }
  return ids;
}

/**
 * الميعاد اللي يتسأل عنه الصبح ده، أو null. [todayStartMs] = نص ليل النهارده بتوقيت الحساب؛
 * «امبارح» = الـ٢٤ ساعة اللي قبله. أكتر من واحد ⇒ آخرهم (الأقرب في الذاكرة).
 */
export function followUpCandidate(
  rows: readonly FollowUpAppointment[],
  todayStartMs: number,
  asked: ReadonlySet<string>,
): AppointmentFollowUp | null {
  const from = todayStartMs - DAY_MS;
  const fits = rows.filter((a) => {
    const t = Date.parse(a.starts_at);
    return Number.isFinite(t) && t >= from && t < todayStartMs &&
      (a.recurrence ?? "once") === "once" && a.status !== "cancelled" &&
      !asked.has(a.id) && isVisit(a);
  }).sort((a, b) => Date.parse(b.starts_at) - Date.parse(a.starts_at));
  const a = fits[0];
  if (!a) return null;
  return {
    id: a.id,
    title: a.title.trim(),
    kind: a.kind ?? "other",
    on: new Date(from + DAY_MS / 2).toISOString().slice(0, 10),
    question: followUpQuestion(a),
  };
}

// deno-lint-ignore no-explicit-any
type Sb = any;

/** القراية: مواعيد امبارح + اللي اتسأل عنه. أي فشل ⇒ null (سؤال ناقص أحسن من سؤال متكرر). */
export async function loadAppointmentFollowUp(
  sb: Sb,
  userId: string,
  todayStartIso: string,
): Promise<AppointmentFollowUp | null> {
  const todayStartMs = Date.parse(todayStartIso);
  if (!Number.isFinite(todayStartMs)) return null;
  try {
    const [apptRes, askedRes] = await Promise.all([
      sb.from("zad_appointments").select("id,title,kind,starts_at,recurrence,status")
        .eq("user_id", userId).eq("recurrence", "once").neq("status", "cancelled")
        .gte("starts_at", new Date(todayStartMs - DAY_MS).toISOString())
        .lt("starts_at", todayStartIso)
        .order("starts_at", { ascending: false }).limit(20),
      sb.from("zad_voice_moments").select("facts")
        .eq("user_id", userId).eq("moment", "morning_greeting").eq("status", "sent")
        .gte("created_at", new Date(todayStartMs - ASKED_LOOKBACK_DAYS * DAY_MS).toISOString()),
    ]);
    if (apptRes.error || askedRes.error) return null;
    return followUpCandidate(
      (apptRes.data ?? []) as FollowUpAppointment[],
      todayStartMs,
      askedFollowUpIds(askedRes.data as Array<{ facts?: unknown }>),
    );
  } catch (e) {
    console.warn("[appointment-follow-up] read failed:", (e as Error)?.message);
    return null;
  }
}
