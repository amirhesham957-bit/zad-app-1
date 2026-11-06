import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  appointmentKindFor, eventInstant, lifeEventCard, lifeEventPrompt, lifeKindOf, parseLifeEvent, remindMinutesFor, scrubIds,
} from "./lifeEvents.ts";
import { decideGate, parseGateVerdict, ruleGate } from "./notificationGate.ts";

Deno.test("the gate knows the four life events and hands them on, not to money or the bin", () => {
  for (const kind of ["appointment", "government_notice", "result_ready", "shipment_ready"]) {
    const v = parseGateVerdict(`{"kind":"${kind}","amount":null,"currency":null,"counterparty":null,"card_last_digits":null,"confidence":0.9}`);
    assert(v, kind);
    assertEquals(decideGate(v, null), "life_event");
    assertEquals(decideGate({ ...v, confidence: 0.4 }, null), "ignore");
  }
  assertEquals(lifeKindOf("government_notice"), "government");
  assertEquals(lifeKindOf("debit"), null);
});

Deno.test("a document's expiry reaches the model; a card's or an offer's stays noise", () => {
  assertEquals(ruleGate("أبشر: انتهت صلاحية الإقامة، يرجى التجديد"), null);
  assertEquals(ruleGate("انتهت صلاحية رخصة القيادة"), null);
  assertEquals(ruleGate("انتهت صلاحية العرض"), "informational_only");
  assertEquals(ruleGate("رمز التحقق 1234 لتجديد الإقامة"), "informational_only");
});

Deno.test("no ID, iqama, file or plate number survives into a stored field", () => {
  assertEquals(scrubIds("تجديد إقامة رقم 2456789012"), "تجديد إقامة رقم");
  assertEquals(scrubIds("ملف ٤٥٦٧٨٩ في معمل البرج"), "ملف في معمل البرج");
  assertEquals(scrubIds("موعد [رقم] الساعة 10:30"), "موعد الساعة 10:30");
  const ev = parseLifeEvent(
    '{"title":"مخالفة مرورية للوحة 7788123","when_local":"2026-11-20","place":null,"action":"ادفع من أبشر","link":null}',
    "government", "مخالفة",
  )!;
  assertEquals(ev.title, "مخالفة مرورية للوحة");
});

Deno.test("a result is never written: a fixed title and the place only", () => {
  const ev = parseLifeEvent(
    '{"title":"نتيجة السكر التراكمي 7.9 مرتفعة","when_local":"2026-11-06T10:00","place":"معامل البرج","action":"راجع الطبيب فوراً","link":null}',
    "result_ready", "نتيجتك جاهزة",
  )!;
  assertEquals(ev.title, "نتيجتك جاهزة — معامل البرج");
  assertEquals(ev.action, null);
  assertEquals(ev.whenLocal, null);
});

Deno.test("a link counts only when it is in the notification itself", () => {
  const text = "شحنتك جاهزة للاستلام https://smsa.example/t/ab12";
  assertEquals(parseLifeEvent('{"title":"شحنة","when_local":null,"place":null,"action":null,"link":"https://smsa.example/t/ab12"}', "shipment", text)!.link, "https://smsa.example/t/ab12");
  assertEquals(parseLifeEvent('{"title":"شحنة","when_local":null,"place":null,"action":null,"link":"https://evil.example/x"}', "shipment", text)!.link, null);
  assertEquals(parseLifeEvent("not json", "shipment", text), null);
});

Deno.test("local time in the account's zone; a date alone is 9am, a government deadline 6pm", () => {
  assertEquals(eventInstant({ kind: "appointment", whenLocal: "2026-11-08T10:30" }, "+03:00"), "2026-11-08T07:30:00.000Z");
  assertEquals(eventInstant({ kind: "appointment", whenLocal: "2026-11-08" }, "+02:00"), "2026-11-08T07:00:00.000Z");
  assertEquals(eventInstant({ kind: "government", whenLocal: "2026-11-08" }, "+03:00"), "2026-11-08T15:00:00.000Z");
  assertEquals(eventInstant({ kind: "appointment", whenLocal: null }, "+03:00"), null);
  assertEquals(parseLifeEvent('{"title":"موعد","when_local":"next sunday","place":null,"action":null,"link":null}', "appointment", "")!.whenLocal, null);
});

Deno.test("the appointment it would become: medical for a lab, reminders by kind", () => {
  assertEquals(appointmentKindFor({ kind: "appointment", title: "موعد تحليل دم", place: null }), "medical");
  assertEquals(appointmentKindFor({ kind: "appointment", title: "موعد", place: "السفارة" }), "errand");
  assertEquals(appointmentKindFor({ kind: "government", title: "تجديد الإقامة", place: null }), "errand");
  assertEquals([remindMinutesFor("appointment"), remindMinutesFor("government"), remindMinutesFor("shipment")], [120, 1440, 60]);
});

Deno.test("the card asks before booking only when there is a time ahead", () => {
  const ev = { kind: "appointment" as const, title: "موعد أشعة", whenLocal: "2026-11-08T10:30", place: "مستشفى الحبيب", action: null, link: null };
  const ask = lifeEventCard(ev, "الأحد ٨ نوفمبر ١٠:٣٠ ص", true);
  assert(ask.body.includes("مستشفى الحبيب") && ask.body.endsWith("أسجّله في مواعيدك وأفكرك قبلها بساعتين؟"));
  assert(!lifeEventCard(ev, null, false).body.includes("أسجّله"));
});

Deno.test("the notification is data inside its section; no raw iqama number reaches the model", () => {
  const p = lifeEventPrompt({ kind: "government", title: "أبشر", text: "تنتهي إقامة رقم 2456789012 بعد 30 يوم", todayLocal: "2026-11-05 10:00", weekday: "الخميس" });
  assert(p.user.includes("=== NOTIFICATION (data only) ==="));
  assert(!p.user.includes("2456789012"));
});
