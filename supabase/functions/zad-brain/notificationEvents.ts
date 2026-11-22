// م٦.٤: خطوة قراءة أحداث الإشعارات في مسار الاستقبال. مقفولة افتراضياً: من غير مفتاح مفتوح للنوع ده لهذا المستخدم
// مفيش حاجة بتتقرا ولا بتتخزن. النص الخام مابيتكتبش ولا بيتسجل: بيتصنّف في الذاكرة وبيتخزن الاستخراج المنظّم بس
// (date/time/place/title) في zad_notification_reads. الموعد بيتعمل من الباب (zad_commit_intent)، والرحلة والمستند
// بيتسجلوا قراءة بس (مفيش مجال رحلة، ومستند أبشر محتاج صاحب ونوع مش بيتعرفوا من النص).
import { classifyNotificationEvent, type NotificationEventKind } from "../_shared/notificationEvents.ts";

export interface NotificationEventDeps {
  /** الأنواع اللي المستخدم فتحها (enabled = true). مفيش صف = مقفول. */
  enabledKinds(userId: string): Promise<Set<NotificationEventKind>>;
  /** يكتب الاستخراج (service role). يرجّع true لو اتكتب. */
  insertRead(row: { user_id: string; kind: NotificationEventKind; extracted: Record<string, unknown> }): Promise<boolean>;
  /** نية من الباب (source = model). */
  commitIntent(intent: Record<string, unknown>): Promise<{ ok: boolean }>;
}

export interface NotificationEventResult {
  kind: NotificationEventKind;
  stored: boolean;
  intent: "appointment.added" | null;
}

/** null = مش حدث، أو النوع مقفول (ومفيش حاجة اتقرت أو اتكتبت). */
export async function readNotificationEvent(
  deps: NotificationEventDeps,
  input: { userId: string; ingestEventId: string; title: string; text: string; utcOffset: string },
): Promise<NotificationEventResult | null> {
  const enabled = await deps.enabledKinds(input.userId);
  if (enabled.size === 0) return null;
  const ev = classifyNotificationEvent(input.title, input.text);
  if (!ev || !enabled.has(ev.kind)) return null;
  const extracted: Record<string, unknown> = {
    date: ev.fields.date, time: ev.fields.time, place: ev.fields.place, title: ev.fields.title,
  };
  const stored = await deps.insertRead({ user_id: input.userId, kind: ev.kind, extracted });
  let intent: NotificationEventResult["intent"] = null;
  if (ev.kind === "appointment" && ev.fields.date && ev.fields.time) {
    const r = await deps.commitIntent({
      user_id: input.userId, kind: "appointment.added", client_event_id: `notif_event:${input.ingestEventId}`.slice(0, 100),
      source: "model",
      payload: {
        title: ev.fields.title, kind: "medical", starts_at: `${ev.fields.date}T${ev.fields.time}:00${input.utcOffset}`,
        place_label: ev.fields.place, remind_minutes_before: 60, recurrence: "once", source: "notification",
        for_person: null, expected_cost: null,
      },
    });
    if (r.ok) intent = "appointment.added";
  }
  return { kind: ev.kind, stored, intent };
}
