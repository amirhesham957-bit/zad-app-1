// circumstances.ts — حالة البيت (ZAD_LIVING_BRAIN.md الشريحة ٢٩، طلب المالك ٢٠٢٦-١٠-٠٤).
//
// «رادار الظروف الاستثنائية: تأجيل التذكيرات غير العاجلة فور رصد ضغوط طارئة كالمرض»، و«وعي فترة التعافي: يقلل التنبيهات
// تلقائياً بعد الفعاليات المجهدة (كالسفر أو الامتحانات)».
//
// طبقة واحدة بتقول زاد يتكلم قد إيه، وكل القنوات بتسألها (منسّق الانتباه، لحظات الصوت، جولة فريق زاد، سؤال الصبح، الشات):
//   - **exceptional** — ظرف طارئ أو امتحانات **قالهم العميل** (set_life_circumstance)، أو استغاثة في شات العيلة آخر ٢٤ ساعة.
//     الصحة والأمان بس (الصيدلية، العيلة، الجرعات، المواعيد) — والباقي بيستنى في الصندوق.
//   - **recovery** — ٤٨ ساعة بعد ما ظرف يخلص (طارئ، امتحانات، رحلة يومين أو أكتر، استغاثة): أقل من العادي.
//   - **normal**.
//
// الرادار **مابيستنتجش**: لا مرض من مشتريات صيدلية ولا مزاج من كلام (§٨ — نفس رفض «رصد الإرهاق»). المصدر يا العميل قال،
// يا حدث موضوعي (استغاثة، رجوع من سفر). والعميل بينهي الهدوء بزرار («رجّع التنبيهات»)؛ ساعتها مفيش تعافي بعده.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

const HOUR = 3_600_000;

/** فترة التعافي بعد ما الظرف يخلص. */
export const RECOVERY_HOURS = 48;
/** استغاثة العيلة بتهدّي زاد اليوم ده. */
export const SOS_QUIET_HOURS = 24;
/** ظرف العميل: الافتراضي والأقصى بالأيام. */
export const DECLARED_DEFAULT_DAYS = 3;
export const DECLARED_MAX_DAYS = 14;

export type CircumstanceMode = "normal" | "recovery" | "exceptional";
export type QuietKind = "exceptional" | "exams";

export interface CircumstanceRow {
  id: string;
  kind: string;
  source?: string | null;
  started_at: string;
  ends_at: string;
  ended_at?: string | null;
  detail?: Record<string, unknown> | null;
}

export interface Circumstance {
  mode: CircumstanceMode;
  /** exceptional | exams | family_sos | after_exceptional | after_exams | after_travel | after_family_sos */
  reason: string | null;
  until: string | null;
  /** الظرف اللي العميل يقدر ينهيه («رجّع التنبيهات») — exceptional/exams بس. */
  id: string | null;
}

export const NORMAL: Circumstance = { mode: "normal", reason: null, until: null, id: null };

const QUIET_KINDS = new Set(["exceptional", "exams"]);
const RECOVER_AFTER = new Set(["exceptional", "exams", "travel"]);

/** الحالة دلوقتي من الظروف وآخر استغاثة في العيلة. قرار نقي. */
export function circumstanceFrom(rows: readonly CircumstanceRow[], sosAt: string | null, now: number): Circumstance {
  const active = rows
    .filter((r) => QUIET_KINDS.has(r.kind) && !r.ended_at && Date.parse(r.started_at) <= now && Date.parse(r.ends_at) > now)
    .sort((a, b) => (a.kind === "exceptional" ? -1 : 0) - (b.kind === "exceptional" ? -1 : 0) || Date.parse(b.ends_at) - Date.parse(a.ends_at));
  if (active.length) return { mode: "exceptional", reason: active[0].kind, until: active[0].ends_at, id: active[0].id };

  const sos = sosAt ? Date.parse(sosAt) : NaN;
  if (Number.isFinite(sos) && now - sos >= 0 && now - sos < SOS_QUIET_HOURS * HOUR) {
    return { mode: "exceptional", reason: "family_sos", until: new Date(sos + SOS_QUIET_HOURS * HOUR).toISOString(), id: null };
  }

  let recovery: Circumstance | null = null;
  const consider = (endMs: number, reason: string) => {
    if (!Number.isFinite(endMs) || now < endMs || now - endMs >= RECOVERY_HOURS * HOUR) return;
    const until = new Date(endMs + RECOVERY_HOURS * HOUR).toISOString();
    if (!recovery || until > (recovery.until ?? "")) recovery = { mode: "recovery", reason, until, id: null };
  };
  for (const r of rows) {
    if (!RECOVER_AFTER.has(r.kind) || r.detail?.ended_by_customer === true) continue;
    consider(Date.parse(r.ended_at ?? r.ends_at), `after_${r.kind}`);
  }
  if (Number.isFinite(sos)) consider(sos + SOS_QUIET_HOURS * HOUR, "after_family_sos");
  return recovery ?? NORMAL;
}

/** زاد يتكلم قد إيه في كل قناة. */
export interface AttentionBudget {
  /** ملاحظات فريق زاد في كل رد شات. */
  chatNotes: number;
  /** ملاحظات في برومبت التحليل اليومي. */
  dailyNotes: number;
  /** كروت مفتوحة قدام العميل (غير الحرج). */
  openCards: number;
  /** لحظات الصوت في اليوم (من غير الجرعات والمواعيد والأمان). */
  voiceCap: number;
  /** فريق زاد: مين يتكلم. الباقي بيستنى في الصندوق (مش بيتمسح). */
  senders: ReadonlySet<string> | null;
  /** سؤال الفضول/الملف الصبح. */
  curiosity: boolean;
}

const ALL_BUDGET: AttentionBudget = { chatNotes: 2, dailyNotes: 4, openCards: 3, voiceCap: 5, senders: null, curiosity: true };

export function attentionBudget(mode: CircumstanceMode | null | undefined): AttentionBudget {
  switch (mode) {
    case "exceptional":
      return { chatNotes: 1, dailyNotes: 1, openCards: 1, voiceCap: 2, senders: new Set(["pharmacy", "family"]), curiosity: false };
    case "recovery":
      // التعافي: أقل، ومن غير المدرّب (الإعداد، «زي النهارده») والباحث — مش وقت حاجات جديدة.
      return {
        chatNotes: 1, dailyNotes: 2, openCards: 2, voiceCap: 3,
        senders: new Set(["pharmacy", "family", "finance", "home", "pantry"]), curiosity: false,
      };
    default:
      return ALL_BUDGET;
  }
}

/** الحالة من الداتابيز. فشل القراية = normal (ماينفعش عطل يسكّت زاد). */
export async function loadCircumstance(sb: SupabaseClient, userId: string, now = Date.now()): Promise<Circumstance> {
  try {
    const since = new Date(now - (RECOVERY_HOURS + SOS_QUIET_HOURS) * HOUR).toISOString();
    const [{ data: rows, error }, { data: member }] = await Promise.all([
      sb.from("zad_life_circumstances").select("id,kind,source,started_at,ends_at,ended_at,detail")
        .eq("user_id", userId).gte("ends_at", since).order("ends_at", { ascending: false }).limit(20),
      sb.from("family_members").select("family_id").eq("user_id", userId).maybeSingle(),
    ]);
    if (error) return NORMAL;
    let sosAt: string | null = null;
    const familyId = (member as { family_id?: string | null } | null)?.family_id ?? null;
    if (familyId) {
      const { data: sos } = await sb.from("chat_messages").select("created_at")
        .eq("family_id", familyId).eq("message_type", "SOS").gte("created_at", since)
        .order("created_at", { ascending: false }).limit(1).maybeSingle();
      sosAt = (sos as { created_at?: string } | null)?.created_at ?? null;
    }
    return circumstanceFrom((rows ?? []) as CircumstanceRow[], sosAt, now);
  } catch {
    return NORMAL;
  }
}
