// المنسّق ٥ (ZAD_PLAN ١.٦): المبادرات الاختيارية بتستنى الساعة اللي العميل ده بيرد فيها.
import { assertEquals } from "jsr:@std/assert@1";
import { isOptionalProactive, responsiveHourDecision, RESPONSIVE_MIN_EVENTS } from "./shared.ts";

const TZ = "Africa/Cairo"; // +03:00 في أكتوبر ٢٠٢٦
const hoursWith = (counts: Record<number, number>) => Array.from({ length: 24 }, (_, h) => counts[h] ?? 0);
// بيرد بالليل بس: ٩ و١٠ (٢١–٢٢ محلي)، ١٤ رد.
const EVENINGS = hoursWith({ 21: 8, 22: 6 });
const NOON = Date.parse("2026-10-18T09:00:00Z"); // ١٢ الضهر القاهرة

Deno.test("an optional nudge at noon waits for the evening hour this customer replies in", () => {
  // ٢٠ محلي جار لـ٢١ ⇐ بيعدّ «بيرد فيها» (±١).
  assertEquals(responsiveHourDecision("predicted_shortage", EVENINGS, TZ, NOON), { action: "postpone", until: "2026-10-18T17:00:00.000Z" });
});

Deno.test("inside a responsive hour it goes out now", () => {
  assertEquals(responsiveHourDecision("predicted_shortage", EVENINGS, TZ, Date.parse("2026-10-18T18:30:00Z")), { action: "deliver" });
});

Deno.test("after the last responsive hour it waits for tomorrow's, never inside their sleep", () => {
  // بيرد ٨ الصبح بس. الساعة ١١ بالليل ⇐ بكرة ٧ (جار لـ٨، وأول ساعة بعد الهدوء ١١–٧).
  const mornings = hoursWith({ 8: 14 });
  assertEquals(responsiveHourDecision("habit_budget", mornings, TZ, Date.parse("2026-10-18T20:00:00Z")),
    { action: "postpone", until: "2026-10-19T04:00:00.000Z" });
  // بيرد ٣ الفجر بس (جوه النوم) ⇐ مفيش ساعة صاحي بيرد فيها ⇐ تطلع.
  assertEquals(responsiveHourDecision("habit_budget", hoursWith({ 3: 14 }), TZ, NOON), { action: "deliver" });
});

Deno.test("too little data keeps the old behaviour", () => {
  assertEquals(responsiveHourDecision("predicted_shortage", hoursWith({ 21: RESPONSIVE_MIN_EVENTS - 1 }), TZ, NOON), { action: "deliver" });
  assertEquals(responsiveHourDecision("predicted_shortage", null, TZ, NOON), { action: "deliver" });
  assertEquals(responsiveHourDecision("predicted_shortage", [1, 2, 3], TZ, NOON), { action: "deliver" });
});

Deno.test("urgent and critical kinds never wait for a reply hour", () => {
  for (const k of ["listener_gap_alert", "spending_ahead", "bill_reminder", "med_followup", "store_arrival", "reminder", ""]) {
    assertEquals(isOptionalProactive(k), false, k);
    assertEquals(responsiveHourDecision(k, EVENINGS, TZ, NOON), { action: "deliver" }, k);
  }
  for (const k of ["predicted_shortage", "restock_link", "habit_budget", "spend_forecast", "home_weekly_digest", "goal_review", "pet_call"]) {
    assertEquals(isOptionalProactive(k), true, k);
  }
});

Deno.test("a late sleeper's own window is respected", () => {
  // نافذة ١–١٠: الساعة ١١ بالليل مش هدوء عنده ⇐ لو بيرد ١١ بتطلع.
  assertEquals(responsiveHourDecision("goal_review", hoursWith({ 23: 14 }), TZ, Date.parse("2026-10-18T20:00:00Z"), { start: 1, end: 10 }),
    { action: "deliver" });
});
