import { assert, assertEquals } from "jsr:@std/assert@1";
import { classifyNotificationEvent, extractDate, extractTime, type NotificationEventKind } from "../_shared/notificationEvents.ts";
import { type NotificationEventDeps, readNotificationEvent } from "./notificationEvents.ts";

const DOCTOR = { title: "صحتي", text: "تم تأكيد حجزك مع د. أحمد في عيادة النور يوم 01/12/2026 الساعة 10:30 ص. رقم الحجز 987654321" };
const FLIGHT = { title: "Saudia", text: "Booking confirmed. Flight SV1234 to Cairo departs 2026-12-05 at 17:45. E-ticket 1234567890123" };
const ABSHER = { title: "أبشر", text: "تنبيه: إقامتك تنتهي بتاريخ ٢٠٢٦/١٢/٣١ — يرجى التجديد. رقم الإقامة ٢٣٤٥٦٧٨٩٠١" };

Deno.test("classifies the three kinds, Saudi and Egyptian wording", () => {
  const a = classifyNotificationEvent(DOCTOR.title, DOCTOR.text)!;
  assertEquals(a.kind, "appointment");
  assertEquals(a.fields.date, "2026-12-01");
  assertEquals(a.fields.time, "10:30");
  assertEquals(a.fields.place, "عيادة النور");
  const t = classifyNotificationEvent(FLIGHT.title, FLIGHT.text)!;
  assertEquals(t.kind, "trip");
  assertEquals(t.fields.date, "2026-12-05");
  assertEquals(t.fields.time, "17:45");
  assertEquals(t.fields.place, "Cairo");
  const d = classifyNotificationEvent(ABSHER.title, ABSHER.text)!;
  assertEquals(d.kind, "document_due");
  assertEquals(d.fields.title, "تجديد الإقامة");
  assertEquals(d.fields.date, "2026-12-31");
  const eg = classifyNotificationEvent("مصر للطيران", "تأكيد حجز رحلتك إلى جدة")!;
  assertEquals(eg.kind, "trip");
  const eg2 = classifyNotificationEvent("", "تم حجز موعدك عند الدكتور محمود بمستشفى السلام")!;
  assertEquals(eg2.kind, "appointment");
});

Deno.test("money, OTP and chatter are not events", () => {
  assertEquals(classifyNotificationEvent("", "تم خصم 200 ريال من بطاقتك في عيادة النور"), null);
  assertEquals(classifyNotificationEvent("", "رمز التحقق 1234 لتأكيد حجز الطيران"), null);
  assertEquals(classifyNotificationEvent("", "صباح الخير يا حبيبي"), null);
});

Deno.test("fields carry no id numbers and no free text", () => {
  for (const n of [DOCTOR, FLIGHT, ABSHER]) {
    const json = JSON.stringify(classifyNotificationEvent(n.title, n.text));
    assert(!/\d{5,}/.test(json), json);
    assert(!json.includes("987654321") && !json.includes("1234567890123") && !json.includes("٢٣٤٥٦٧٨٩٠١"));
  }
});

Deno.test("date and time parsing", () => {
  assertEquals(extractDate("٠١/١٢/٢٠٢٦"), "2026-12-01");
  assertEquals(extractDate("31/02/2026"), null);
  assertEquals(extractDate("1447/05/10"), null);
  assertEquals(extractTime("الساعة 5:15 م"), "17:15");
  assertEquals(extractTime("12:05 AM"), "00:05");
  assertEquals(extractTime("25:00"), null);
});

function fakeDeps(enabled: NotificationEventKind[]) {
  const reads: Record<string, unknown>[] = [];
  const intents: Record<string, unknown>[] = [];
  const logs: string[] = [];
  const deps: NotificationEventDeps = {
    enabledKinds: () => Promise.resolve(new Set(enabled)),
    insertRead: (row) => (reads.push(row), Promise.resolve(true)),
    commitIntent: (i) => (intents.push(i), Promise.resolve({ ok: true })),
  };
  return { deps, reads, intents, logs };
}
const run = (deps: NotificationEventDeps, n: { title: string; text: string }) =>
  readNotificationEvent(deps, { userId: "u1", ingestEventId: "e1", ...n, utcOffset: "+03:00" });

Deno.test("switch off (default) => nothing read, nothing written", async () => {
  const f = fakeDeps([]);
  assertEquals(await run(f.deps, DOCTOR), null);
  assertEquals(f.reads.length + f.intents.length, 0);
  // a different kind on => this kind still writes nothing
  const g = fakeDeps(["trip"]);
  assertEquals(await run(g.deps, DOCTOR), null);
  assertEquals(g.reads.length + g.intents.length, 0);
});

Deno.test("switch on => structured read only, raw text never written", async () => {
  const f = fakeDeps(["appointment", "trip", "document_due"]);
  for (const n of [DOCTOR, FLIGHT, ABSHER]) await run(f.deps, n);
  assertEquals(f.reads.length, 3);
  const written = JSON.stringify([f.reads, f.intents]);
  for (const raw of [DOCTOR, FLIGHT, ABSHER]) {
    for (const piece of [raw.text, raw.title === "صحتي" ? "تم تأكيد حجزك" : raw.title, "987654321", "1234567890123", "SV1234", "٢٣٤٥٦٧٨٩٠١", "E-ticket", "يرجى التجديد"]) {
      assert(!written.includes(piece), `raw piece leaked: ${piece}`);
    }
  }
  for (const r of f.reads) assertEquals(Object.keys(r.extracted as object).sort(), ["date", "place", "time", "title"]);
});

Deno.test("appointment with date and time goes through the door as source model; trip and document only record", async () => {
  const f = fakeDeps(["appointment", "trip", "document_due"]);
  const a = await run(f.deps, DOCTOR);
  assertEquals(a?.intent, "appointment.added");
  assertEquals(f.intents.length, 1);
  const i = f.intents[0] as { source: string; kind: string; client_event_id: string; payload: Record<string, unknown> };
  assertEquals(i.source, "model");
  assertEquals(i.kind, "appointment.added");
  assertEquals(i.client_event_id, "notif_event:e1");
  assertEquals(i.payload.starts_at, "2026-12-01T10:30:00+03:00");
  assertEquals(i.payload.source, "notification");
  assertEquals((await run(f.deps, FLIGHT))?.intent, null);
  assertEquals((await run(f.deps, ABSHER))?.intent, null);
  assertEquals(f.intents.length, 1);
  // appointment without a time: recorded, no intent
  const g = fakeDeps(["appointment"]);
  const r = await run(g.deps, { title: "", text: "تم تأكيد حجزك مع الدكتور سامي" });
  assertEquals(r?.stored, true);
  assertEquals(g.intents.length, 0);
});

Deno.test("mutation: a deps that ignores the switch would write; the guard is the enabledKinds check", async () => {
  // if enabledKinds were bypassed (all kinds on) the DOCTOR read is written, so the switch-off test above is meaningful.
  const on = fakeDeps(["appointment"]);
  assert((await run(on.deps, DOCTOR)) !== null);
  assertEquals(on.reads.length, 1);
});

Deno.test("the index wiring checks the switch before classifying and never logs the text", async () => {
  const src = await Deno.readTextFile(new URL("./notificationEvents.ts", import.meta.url));
  assert(src.indexOf("enabled.size === 0") < src.indexOf("classifyNotificationEvent(input"));
  assert(!/console\./.test(src));
  const shared = await Deno.readTextFile(new URL("../_shared/notificationEvents.ts", import.meta.url));
  assert(!/console\./.test(shared));
});
