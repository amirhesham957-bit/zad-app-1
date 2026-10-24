// المنسّق ٣: سقف يومي للبيت — اتنين مبادرات (مهام) في يومه، والزيادة تستنى بكرة الصبح.
import { assertEquals } from "jsr:@std/assert@1";
import { dailyCapDecision, PACING_DAILY_CAP } from "./shared.ts";

const TZ = "Africa/Cairo"; // +03:00 في أكتوبر ٢٠٢٦
const NOW = Date.parse("2026-10-18T15:00:00Z"); // ٦ المغرب القاهرة
const at = (iso: string) => ({ at: iso });

Deno.test("two proactive tasks today: the third waits for 7 a.m. tomorrow", () => {
  const sent = [
    { kind: "spending_ahead", ...at("2026-10-18T06:00:00Z") },
    { kind: "predicted_shortage", ...at("2026-10-18T10:00:00Z") },
  ];
  assertEquals(PACING_DAILY_CAP, 2);
  assertEquals(dailyCapDecision("spend_forecast", sent, TZ, NOW), { action: "postpone", until: "2026-10-19T04:00:00.000Z" });
});

Deno.test("one sent today: the next goes out", () => {
  assertEquals(dailyCapDecision("spend_forecast", [{ kind: "spending_ahead", ...at("2026-10-18T06:00:00Z") }], TZ, NOW), { action: "deliver" });
});

Deno.test("yesterday's tasks (by the account's clock, not UTC) don't count", () => {
  // ١١:٣٠ بالليل القاهرة يوم ١٧ = ٢٠:٣٠ UTC
  const sent = [
    { kind: "spending_ahead", ...at("2026-10-17T20:30:00Z") },
    { kind: "bill_reminder", ...at("2026-10-17T18:00:00Z") },
  ];
  assertEquals(dailyCapDecision("spend_forecast", sent, TZ, NOW), { action: "deliver" });
});

Deno.test("moments, check-ins, medicine and store arrivals are not counted", () => {
  const sent = [
    { kind: "moment:morning_greeting", ...at("2026-10-18T04:05:00Z") },
    { kind: "checkin", ...at("2026-10-18T05:00:00Z") },
    { kind: "med_followup", ...at("2026-10-18T07:00:00Z") },
    { kind: "store_arrival", ...at("2026-10-18T08:00:00Z") },
    { kind: "reminder", ...at("2026-10-18T09:00:00Z") },
    { kind: "spending_ahead", ...at("2026-10-18T10:00:00Z") },
  ];
  assertEquals(dailyCapDecision("spend_forecast", sent, TZ, NOW), { action: "deliver" });
});

Deno.test("the bank going silent, medicine, store arrivals and requests are never capped", () => {
  const full = [
    { kind: "spending_ahead", ...at("2026-10-18T06:00:00Z") },
    { kind: "predicted_shortage", ...at("2026-10-18T10:00:00Z") },
  ];
  for (const k of ["listener_gap_alert", "med_followup", "store_arrival", "reminder", ""]) {
    assertEquals(dailyCapDecision(k, full, TZ, NOW), { action: "deliver" }, k);
  }
});

Deno.test("a late sleeper's morning is their wake hour", () => {
  const sent = [
    { kind: "spending_ahead", ...at("2026-10-18T06:00:00Z") },
    { kind: "predicted_shortage", ...at("2026-10-18T10:00:00Z") },
  ];
  assertEquals(dailyCapDecision("goal_review", sent, TZ, NOW, { start: 1, end: 10 }), { action: "postpone", until: "2026-10-19T07:00:00.000Z" });
});

// ── المنسّق ٤ (ZAD_PLAN ١.٤): التوزيع بدل التكويم ──
import { capSlot, outlivesShelf } from "./shared.ts";

const FULL = [
  { kind: "spending_ahead", at: "2026-10-18T06:00:00Z" },
  { kind: "predicted_shortage", at: "2026-10-18T10:00:00Z" },
];

Deno.test("over the cap, the next ones take tomorrow's slots instead of all landing on the wake hour", () => {
  // بنك ٧ الصبح (٠٤:٠٠ UTC) مأخوذ بحاجة أهم ⇐ التوقّع ياخد ٩.
  const parked = [{ kind: "bill_reminder", at: "2026-10-19T04:00:00.000Z" }];
  assertEquals(dailyCapDecision("spend_forecast", FULL, TZ, NOW, undefined, parked), { action: "postpone", until: "2026-10-19T06:00:00.000Z" });
  // الأهم مايتزقّش ورا الأقل أهمية: الفاتورة تاخد الصحيان حتى لو الرفيق متأجل عليه.
  assertEquals(dailyCapDecision("bill_reminder", FULL, TZ, NOW, undefined, [{ kind: "pet_call", at: "2026-10-19T04:00:00.000Z" }]),
    { action: "postpone", until: "2026-10-19T04:00:00.000Z" });
});

Deno.test("capSlot ignores tasks parked on other days", () => {
  const wake = Date.parse("2026-10-19T04:00:00Z");
  assertEquals(capSlot("goal_review", wake, [
    { kind: "bill_reminder", at: "2026-10-18T16:00:00Z" },
    { kind: "bill_reminder", at: "2026-10-20T04:00:00Z" },
  ]), "2026-10-19T04:00:00.000Z");
  assertEquals(capSlot("goal_review", wake, [
    { kind: "bill_reminder", at: "2026-10-19T04:00:00Z" },
    { kind: "spend_forecast", at: "2026-10-19T06:00:00Z" },
  ]), "2026-10-19T08:00:00.000Z");
});

Deno.test("yesterday's spend forecast is dropped, not sent tomorrow at 7 (the 2026-10-24 row)", () => {
  // اتعمل ٠١:٠٧ UTC يوم ٢٤، والسقف كان هيطلّعه ٠٤:٠٠ يوم ٢٥ = بعد ٢٧ ساعة.
  assertEquals(outlivesShelf("spend_forecast", false, "2026-10-24T01:07:02Z", Date.parse("2026-10-25T04:00:00Z")), true);
  assertEquals(outlivesShelf("spend_forecast", false, "2026-10-24T01:07:02Z", Date.parse("2026-10-24T11:00:00Z")), false);
});

Deno.test("bills, warranties, goal follow-ups, recurring tasks and requests never go stale", () => {
  const born = "2026-10-01T00:00:00Z", late = Date.parse("2026-10-20T00:00:00Z");
  for (const k of ["bill_reminder", "warranty_reminder", "goal_review", "listener_gap_alert", "med_followup", "reminder", ""]) {
    assertEquals(outlivesShelf(k, false, born, late), false, k);
  }
  assertEquals(outlivesShelf("spend_forecast", true, born, late), false);
  assertEquals(outlivesShelf("spend_forecast", false, null, late), false);
});

Deno.test("a missing shortage still matters for two days, a restock link for three", () => {
  const born = "2026-10-18T00:00:00Z";
  assertEquals(outlivesShelf("predicted_shortage", false, born, Date.parse("2026-10-19T20:00:00Z")), false);
  assertEquals(outlivesShelf("predicted_shortage", false, born, Date.parse("2026-10-20T04:00:00Z")), true);
  assertEquals(outlivesShelf("restock_link", false, born, Date.parse("2026-10-20T11:00:00Z")), false);
  assertEquals(outlivesShelf("restock_link", false, born, Date.parse("2026-10-21T04:00:00Z")), true);
});
