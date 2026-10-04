// «يوم مزحوم»: ٣ مواعيد أو أكتر ⇒ اللحظات اللي تقدر تستنى بتستنى، والبيت «ضغطه عالي».
import { assertEquals } from "jsr:@std/assert@1";
import { BUSY_DAY_APPOINTMENTS, momentGate } from "./voiceMoments.ts";
import { appointmentsOnLocalDay, householdLoad } from "./householdLoad.ts";

Deno.test("busy day: optional moments wait, what matters is still said", () => {
  for (const m of ["tasbiha_reminder", "ignored_days", "back_home_spent", "weekly_money_story"]) {
    assertEquals(momentGate(m, 15, 0, BUSY_DAY_APPOINTMENTS), "busy_day", m);
    assertEquals(momentGate(m, 15, 0, BUSY_DAY_APPOINTMENTS - 1), null, `${m} on a normal day`);
  }
  for (const m of ["dose_due", "appointment_soon", "morning_greeting", "family_zone_exit", "budget_100", "place_reminder"]) {
    assertEquals(momentGate(m, 10, 0, 5), null, m);
  }
});

Deno.test("busy day: the household load is high with three appointments today", () => {
  const calm = { threat: "SAFE", available: 4000, budget: 10000, brokeMode: false, localHour: 14 };
  assertEquals(householdLoad({ ...calm, appointmentsToday: 3 }).level, "high");
  assertEquals(householdLoad({ ...calm, appointmentsToday: 3 }).reasons, ["النهارده فيه 3 مواعيد"]);
  assertEquals(householdLoad({ ...calm, appointmentsToday: 2 }).level, "easy");
});

Deno.test("busy day: today is the market's day, not UTC's", () => {
  // 2026-10-04 23:30 in Cairo is already the 4th there, 20:30 UTC.
  const now = new Date("2026-10-04T20:30:00Z");
  const rows = [
    { starts_at: "2026-10-04T07:00:00Z" }, // 10:00 Cairo, today
    { starts_at: "2026-10-04T21:30:00Z" }, // 00:30 the 5th in Cairo — tomorrow there
    { starts_at: "2026-10-03T22:30:00Z" }, // 01:30 the 4th in Cairo — today there
    { starts_at: null },
  ];
  assertEquals(appointmentsOnLocalDay(rows, "Africa/Cairo", now), 2);
});
