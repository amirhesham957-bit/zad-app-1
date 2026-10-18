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
