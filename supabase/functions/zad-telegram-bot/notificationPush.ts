// البوت بيتكلم مع كل إشعار: قرار الإرسال لإشعار واحد من app_notifications (التريجر بيبعته لـ?job=notification_push).
// من غير شبكة: اللقطة بتتحقن. القواعد: مفيش تكرار (إشعار = رسالة)، مفيش في ساعات النوم (الكتم بيتطبّق عند الكاتب: الريستوك مابيكتبش إشعار لو مكتوم)، وسقف يومي (حارس الكلفة).
// النص هو نص الإشعار نفسه: مابنضيفش مصدر ولا مين عمل إيه.
import { isQuietHourIn, localHourIn, quietWindowOf } from "../zad-brain/shared.ts";

/** سقف رسايل الإشعارات في ٢٤ ساعة لكل عميل. فوقه الإشعار يفضل في التطبيق بس. */
export const DAILY_NOTIFICATION_PUSH_CAP = 12;

export interface PushContext {
  /** الإشعار ده اتسجّل قبل كده (المفتاح = id الإشعار). */
  alreadyClaimed: boolean;
  tz: string;
  sleepBed: string | null;
  sleepWake: string | null;
  sentLast24h: number;
}

export type PushDecision =
  | { send: true }
  | { send: false; reason: "duplicate" | "quiet_hours" | "daily_cap" };

export function decideNotificationPush(c: PushContext, nowMs: number): PushDecision {
  if (c.alreadyClaimed) return { send: false, reason: "duplicate" };
  if (isQuietHourIn(localHourIn(c.tz, nowMs), quietWindowOf(c.sleepBed, c.sleepWake))) {
    return { send: false, reason: "quiet_hours" };
  }
  if (c.sentLast24h >= DAILY_NOTIFICATION_PUSH_CAP) return { send: false, reason: "daily_cap" };
  return { send: true };
}

export function notificationText(title: string, body: string): string {
  const t = title.trim();
  const b = body.trim();
  return t && b ? `${t}\n\n${b}` : t || b;
}

/** معرّف الإشعار لازم UUID: ده مفتاح التكرار. */
export function validNotificationId(v: unknown): v is string {
  return typeof v === "string" && /^[0-9a-fA-F-]{36}$/.test(v);
}
