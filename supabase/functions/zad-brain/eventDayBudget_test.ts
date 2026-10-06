import { assertAlmostEquals, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { eventDayBudget, eventDayBudgetRule, eventWeight } from "./eventDayBudget.ts";

const TZ = "Asia/Riyadh"; // +03:00 all year
const NOW = new Date("2026-10-06T09:00:00+03:00"); // a Tuesday morning
const at = (local: string) => new Date(`${local}+03:00`).toISOString();

Deno.test("weights: travel 2, a doctor or an outing 1.5, an errand 1, a recurring or cancelled one 1", () => {
  assertEquals(eventWeight({ title: "سفر إسكندرية" }), 2);
  assertEquals(eventWeight({ title: "دكتور الأسنان" }), 1.5);
  assertEquals(eventWeight({ title: "متابعة", kind: "medical" }), 1.5);
  assertEquals(eventWeight({ title: "خروجة مع العيال" }), 1.5);
  assertEquals(eventWeight({ title: "البنك" }), 1);
  assertEquals(eventWeight({ title: "النادي", recurrence: "weekly" }), 1);
  assertEquals(eventWeight({ title: "دكتور", status: "cancelled" }), 1);
});

Deno.test("a doctor today raises today; the week carries it; the total is unchanged", () => {
  // 1000 over 10 days = 100 a day; week = 7 days, weights 1.5 + 6 ⇒ today = 700 × 1.5 / 7.5 = 140.
  const r = eventDayBudget({
    available: 1000, daysLeft: 10, timeZone: TZ, now: NOW,
    appointments: [{ title: "دكتور الأسنان", starts_at: at("2026-10-06T17:00:00") }],
  })!;
  assertEquals(r.base, 100);
  assertEquals(r.today, 140);
  assertEquals(r.event, { title: "دكتور الأسنان", in_days: 0 });
  // The other six days get 700 / 7.5 = 93.33 each; plus 3 untouched days at 100.
  assertAlmostEquals(r.today + 6 * (700 / 7.5) + 3 * 100, 1000, 0.01);
});

Deno.test("an outing later this week lowers today a little and names it", () => {
  const r = eventDayBudget({
    available: 700, daysLeft: 7, timeZone: TZ, now: NOW,
    appointments: [{ title: "سفر", starts_at: at("2026-10-09T08:00:00") }],
  })!;
  // weights 1,1,1,2,1,1,1 = 8 ⇒ today 700/8 = 87.5
  assertEquals(r.today, 87.5);
  assertEquals(r.event, { title: "سفر", in_days: 3 });
});

Deno.test("nothing to rebalance: no outing, one beyond the week, nothing available, no budget", () => {
  const base = { daysLeft: 10, timeZone: TZ, now: NOW };
  assertEquals(eventDayBudget({ ...base, available: 1000, appointments: [{ title: "البنك", starts_at: at("2026-10-06T12:00:00") }] }), null);
  assertEquals(eventDayBudget({ ...base, available: 1000, appointments: [{ title: "سفر", starts_at: at("2026-10-14T12:00:00") }] }), null);
  assertEquals(eventDayBudget({ ...base, available: 0, appointments: [{ title: "سفر", starts_at: at("2026-10-06T12:00:00") }] }), null);
  assertEquals(eventDayBudget({ ...base, available: null, appointments: [{ title: "سفر", starts_at: at("2026-10-06T12:00:00") }] }), null);
});

Deno.test("the last two days of the cycle: the horizon is the cycle, not a week", () => {
  const r = eventDayBudget({
    available: 200, daysLeft: 2, timeZone: TZ, now: NOW,
    appointments: [{ title: "خروجة", starts_at: at("2026-10-06T20:00:00") }],
  })!;
  assertEquals(r.today, 120); // 200 × 1.5 / 2.5
});

Deno.test("the rule tells the brain to use today and never to call it an estimate", () => {
  const rule = eventDayBudgetRule({ event_day_budget: { today: 140, base: 100, event: { title: "دكتور", in_days: 0 } } });
  assertStringIncludes(rule, "daily_allowance_left");
  assertStringIncludes(rule, "ماتقولش");
  assertEquals(eventDayBudgetRule({ event_day_budget: null }), "");
});
