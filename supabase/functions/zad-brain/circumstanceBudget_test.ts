import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import {
  budgetAtStart,
  circumstanceBudget,
  circumstanceBudgetLine,
  circumstanceBudgetRule,
  circumstanceCost,
} from "./circumstanceBudget.ts";

const START = { available: 3000, days_left: 10, cycle_end: "2026-11-05" };
const at = (available: number, days: number, cost?: number, cycleEnd = "2026-11-05") =>
  circumstanceBudget({ detail: { budget_at_start: START, ...(cost ? { cost } : {}) }, available, daysLeft: days, cycleEnd });

Deno.test("the snapshot's available, days and cycle end are what the circumstance keeps", () => {
  assertEquals(budgetAtStart({ available: 3000, cycle: { days_left: 10, cycle_end: "2026-11-05" } }), START);
  assertEquals(budgetAtStart({ available: "1500.5", cycle: { days_left: 0 } }), { available: 1500.5, days_left: 1, cycle_end: null });
  // No ceiling set ⇒ no available ⇒ nothing to redistribute.
  assertEquals(budgetAtStart({ available: null, cycle: { days_left: 10 } }), null);
  assertEquals(budgetAtStart(null), null);
});

Deno.test("a cost is what the customer said, positive, or nothing", () => {
  assertEquals(circumstanceCost(2000), 2000);
  assertEquals(circumstanceCost("750.456"), 750.46);
  assertEquals(circumstanceCost(0), null);
  assertEquals(circumstanceCost(-5), null);
  assertEquals(circumstanceCost("كتير"), null);
  assertEquals(circumstanceCost(undefined), null);
});

Deno.test("a cost not yet paid is held back and the rest is spread over the days left", () => {
  // 3000 over 10 days = 300; 2000 held for the hospital ⇒ 1000 over 10 = 100.
  assertEquals(at(3000, 10, 2000), {
    daily_before: 300, daily_now: 100, available_now: 3000, days_left: 10, reserved: 2000, short: false,
  });
});

Deno.test("once the cost is paid and logged, the hold is gone and the day is what is left", () => {
  // Paid 2000 two days later: 1000 over 8 days = 125, nothing held.
  assertEquals(at(1000, 8, 2000), {
    daily_before: 300, daily_now: 125, available_now: 1000, days_left: 8, reserved: 0, short: false,
  });
  // Half paid so far: 1000 still held out of 2000.
  assertEquals(at(2000, 9, 2000)!.reserved, 1000);
  assertEquals(at(2000, 9, 2000)!.daily_now, 111.11);
});

Deno.test("no cost said: the day only moves with what was actually spent", () => {
  assertEquals(at(3000, 10)!.reserved, 0);
  assertEquals(at(3000, 10)!.daily_now, 300);
  assertEquals(at(1200, 6)!.daily_now, 200);
});

Deno.test("a hold the money cannot cover is short, with no day to tell", () => {
  // Nothing paid yet and the hospital costs more than what is left.
  const b = at(3000, 10, 4000)!;
  assertEquals(b.short, true);
  assertEquals(b.daily_now, 0);
  assertEquals(b.reserved, 4000);
  // Already below zero.
  assertEquals(at(-200, 5)!.short, true);
});

Deno.test("payday in between, no saved budget, or no available now ⇒ no comparison", () => {
  assertEquals(at(9000, 30, 2000, "2026-12-05"), null);
  assertEquals(circumstanceBudget({ detail: {}, available: 3000, daysLeft: 10, cycleEnd: "2026-11-05" }), null);
  assertEquals(circumstanceBudget({ detail: null, available: 3000, daysLeft: 10, cycleEnd: "2026-11-05" }), null);
  assertEquals(circumstanceBudget({ detail: { budget_at_start: START }, available: null, daysLeft: 10, cycleEnd: "2026-11-05" }), null);
});

Deno.test("the tool's line: the new day, the hold, the short case, and asking the cost when nothing moved", () => {
  const moved = circumstanceBudgetLine(at(3000, 10, 2000), "EGP");
  assertStringIncludes(moved, "يومه 100 EGP بدل 300 EGP");
  assertStringIncludes(moved, "2000 EGP محجوزين للظرف");
  assertStringIncludes(circumstanceBudgetLine(at(3000, 10, 4000), "EGP"), "مفيش مصروف يومي يتقال");
  const still = circumstanceBudgetLine(at(3000, 10), "EGP");
  assertStringIncludes(still, "هيكلّف حوالي كام؟");
  assertStringIncludes(still, "cost");
  assertEquals(circumstanceBudgetLine(null, "EGP"), "");
});

Deno.test("the prompt rule only when there is a circumstance budget", () => {
  assertEquals(circumstanceBudgetRule({ circumstance_budget: null }), "");
  assertEquals(circumstanceBudgetRule(null), "");
  assertStringIncludes(circumstanceBudgetRule({ circumstance_budget: at(3000, 10, 2000) }), "daily_now");
});
