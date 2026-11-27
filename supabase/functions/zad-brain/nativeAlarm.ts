// v2-2: منبّه أندرويد حقيقي خلف ZAD_NATIVE_ALARM (مقفول افتراضياً لحد ما مستقبِل SET_ALARM Intent في Flutter يتشحن).
// السيرفر بيبعت FCM data-only (من غير notification) لأجهزة العميل، والتطبيق هو اللي يفتح Intent المنبّه.
// «اتبعت» مش «اتظبط»: السيرفر مابيعرفش لو الجهاز نفّذ. أي فشل ⇒ fallback لتذكير جوه التطبيق.
// مابيكتبش في أي جدول: بيقرا zad_fcm_tokens بس.
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import type { ToolDef } from "./callModel.ts";
import { FCM_V1_ENDPOINT, getAccessToken, parseServiceAccount } from "./push.ts";

export const NATIVE_ALARM_FLAG = "ZAD_NATIVE_ALARM";
export const NATIVE_ALARM_TOOL_NAME = "set_native_alarm";
export const nativeAlarmEnabled = (): boolean => Deno.env.get(NATIVE_ALARM_FLAG) === "1";

export const NATIVE_ALARM_FLAG_OFF_REFUSAL =
  "مرفوض: ظبط منبّه النظام مش متاح دلوقتي — اعمل تذكير جوه التطبيق وقول للعميل بوضوح إنك ماقدرتش تظبط منبّه على الموبايل.";
export const NATIVE_ALARM_FALLBACK_INSTRUCTION =
  "ماتقولش إن المنبّه اتظبط. اعمل تذكير عادي جوه التطبيق (add_appointment) في نفس الوقت، وقول للعميل بوضوح إنك ماقدرتش تظبط منبّه النظام على الموبايل وإن التذكير جوه زاد بس.";
export const NATIVE_ALARM_SENT_NOTE =
  "الطلب اتبعت لموبايل العميل، مش مضمون إن المنبّه اتظبط فعلاً. قول «بعتّ طلب المنبّه لموبايلك» مش «المنبّه اتظبط».";

/** الأيام: ١=الاتنين … ٧=الأحد (ISO). بتقبل أرقام أو أسماء عربي/إنجليزي. */
const DAY_NAMES: Record<string, number> = {
  "الاتنين": 1, "الاثنين": 1, "اتنين": 1, "monday": 1, "mon": 1,
  "التلات": 2, "الثلاثاء": 2, "تلات": 2, "tuesday": 2, "tue": 2,
  "الاربع": 3, "الأربعاء": 3, "الاربعاء": 3, "اربع": 3, "wednesday": 3, "wed": 3,
  "الخميس": 4, "خميس": 4, "thursday": 4, "thu": 4,
  "الجمعة": 5, "الجمعه": 5, "جمعة": 5, "جمعه": 5, "friday": 5, "fri": 5,
  "السبت": 6, "سبت": 6, "saturday": 6, "sat": 6,
  "الحد": 7, "الأحد": 7, "الاحد": 7, "احد": 7, "أحد": 7, "sunday": 7, "sun": 7,
};

export interface NativeAlarmArgs { hour: number; minute: number; label: string; days: number[] }

export function parseNativeAlarmInput(input: unknown): { value: NativeAlarmArgs } | { error: string } {
  const i = (input ?? {}) as Record<string, unknown>;
  const hour = i.hour, minute = i.minute;
  if (typeof hour !== "number" || !Number.isInteger(hour) || hour < 0 || hour > 23) return { error: "مرفوض: الساعة لازم تكون رقم صحيح من ٠ لـ٢٣." };
  if (typeof minute !== "number" || !Number.isInteger(minute) || minute < 0 || minute > 59) return { error: "مرفوض: الدقايق لازم تكون رقم صحيح من ٠ لـ٥٩." };
  const label = typeof i.label === "string" ? i.label.trim().slice(0, 80) : "";
  if (!label) return { error: "مرفوض: لازم اسم للمنبّه (label)." };
  const days: number[] = [];
  if (i.days !== undefined && i.days !== null) {
    if (!Array.isArray(i.days)) return { error: "مرفوض: الأيام لازم تكون قايمة (١=الاتنين … ٧=الأحد أو أسماء الأيام)." };
    for (const d of i.days) {
      const n = typeof d === "number" ? d : typeof d === "string" ? (DAY_NAMES[d.trim().toLowerCase()] ?? NaN) : NaN;
      if (!Number.isInteger(n) || n < 1 || n > 7) return { error: `مرفوض: يوم غير معروف (${String(d).slice(0, 20)}) — استعمل ١ للاتنين … ٧ للأحد أو اسم اليوم.` };
      if (!days.includes(n)) days.push(n);
    }
    days.sort((a, b) => a - b);
  }
  return { value: { hour, minute, label, days } };
}

export const NATIVE_ALARM_TOOL: ToolDef = {
  name: NATIVE_ALARM_TOOL_NAME,
  description:
    "ظبّط منبّه حقيقي على موبايل العميل (منبّه النظام) في ساعة ودقيقة محددة. السيرفر بيبعت الطلب للجهاز ومابيعرفش لو اتنفّذ: " +
    "قول «بعتّ الطلب لموبايلك» مش «اتظبط». لو الرد فيه status=fallback_to_inapp_reminder اعمل تذكير جوه التطبيق وقول للعميل بوضوح إن منبّه النظام ماتظبطش. " +
    "الوقت لازم يكون من كلام العميل (ماتخمنش).",
  input_schema: {
    type: "object",
    properties: {
      hour: { type: "number", description: "الساعة ٠ لـ٢٣" },
      minute: { type: "number", description: "الدقايق ٠ لـ٥٩" },
      label: { type: "string", description: "اسم المنبّه، مثلاً «صلاة الفجر»" },
      days: {
        type: "array",
        items: { type: "string" },
        description: "اختياري: أيام التكرار (١=الاتنين … ٧=الأحد، أو أسماء الأيام). من غيره المنبّه مرة واحدة.",
      },
    },
    required: ["hour", "minute", "label"],
  },
};

export type AlarmSendResult = "ok" | "failed";
export interface AlarmSender {
  /** false لو FIREBASE_SERVICE_ACCOUNT مش متظبط. */
  configured(): boolean;
  send(token: string, data: Record<string, string>): Promise<AlarmSendResult>;
}

/** data-only: مفيش مفتاح notification أبداً. */
export function buildAlarmMessage(token: string, data: Record<string, string>) {
  return { message: { token, data, android: { priority: "HIGH" } } };
}

/** المُرسِل الحقيقي: FCM v1، data-only، أولوية HIGH. */
export const fcmAlarmSender: AlarmSender = {
  configured: () => !!parseServiceAccount(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? ""),
  async send(token, data) {
    try {
      const sa = parseServiceAccount(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "");
      if (!sa) return "failed";
      const accessToken = await getAccessToken(sa);
      const res = await fetch(FCM_V1_ENDPOINT.replace("{project_id}", sa.project_id), {
        method: "POST",
        headers: { "Content-Type": "application/json", "Authorization": `Bearer ${accessToken}` },
        body: JSON.stringify(buildAlarmMessage(token, data)),
      });
      if (!res.ok) console.error(`native alarm FCM ${res.status}:`, (await res.text().catch(() => "")).slice(0, 300));
      return res.ok ? "ok" : "failed";
    } catch (e) {
      console.error("native alarm FCM threw:", e);
      return "failed";
    }
  },
};

export function alarmData(a: NativeAlarmArgs): Record<string, string> {
  return { action: "SET_NATIVE_ALARM", hour: String(a.hour), minute: String(a.minute), label: a.label, days: JSON.stringify(a.days) };
}

const fallback = (reason: string, a: NativeAlarmArgs): string =>
  JSON.stringify({
    status: "fallback_to_inapp_reminder", reason, hour: a.hour, minute: a.minute, label: a.label, days: a.days,
    instruction: NATIVE_ALARM_FALLBACK_INSTRUCTION,
  });

export async function setNativeAlarm(
  sb: SupabaseClient,
  userId: string,
  input: unknown,
  sender: AlarmSender = fcmAlarmSender,
  enabled: boolean = nativeAlarmEnabled(),
): Promise<string> {
  if (!enabled) return NATIVE_ALARM_FLAG_OFF_REFUSAL;
  const parsed = parseNativeAlarmInput(input);
  if ("error" in parsed) return parsed.error;
  const a = parsed.value;
  if (!sender.configured()) return fallback("fcm_not_configured", a);
  let tokens: string[] = [];
  try {
    const since = new Date(Date.now() - 14 * 86_400_000).toISOString();
    const { data, error } = await sb.from("zad_fcm_tokens").select("token").eq("user_id", userId).gt("updated_at", since);
    if (error) return fallback("token_lookup_failed", a);
    tokens = (data ?? []).map((r: { token: string }) => r.token).filter(Boolean);
  } catch {
    return fallback("token_lookup_failed", a);
  }
  if (!tokens.length) return fallback("no_active_device", a);
  const payload = alarmData(a);
  const results = await Promise.all(tokens.map((t) => sender.send(t, payload).catch((): AlarmSendResult => "failed")));
  const sent = results.filter((r) => r === "ok").length;
  if (!sent) return fallback("send_failed", a);
  return JSON.stringify({ status: "sent", devices: sent, hour: a.hour, minute: a.minute, label: a.label, days: a.days, note: NATIVE_ALARM_SENT_NOTE });
}
