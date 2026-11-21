import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { planRestock, urgency, type RestockItem } from "./pantryPriorities.ts";

Deno.test("budget covers everything", () => {
  const items: RestockItem[] = [
    { id: "rice", price: 20, tier: "essential", daysLeft: 3 },
    { id: "oil", price: 30, tier: "important", daysLeft: 2 },
    { id: "coffee", price: 10, tier: "luxury", daysLeft: 0 },
  ];

  const plan = planRestock(items, 60);

  assertEquals(plan.buy, ["rice", "oil", "coffee"]);
  assertEquals(plan.skip, []);
  assertEquals(plan.spent, 60);
  assertEquals(plan.essentialsShort, []);
});

Deno.test("essentials come before higher-value important items", () => {
  const plan = planRestock([
    { id: "essential", price: 50, tier: "essential", daysLeft: 5 },
    { id: "important", price: 50, tier: "important", daysLeft: 0 },
  ], 50);

  assertEquals(plan.buy, ["essential"]);
  assertEquals(plan.skip, ["important"]);
  assertEquals(plan.spent, 50);
  assertEquals(plan.essentialsShort, []);
});

Deno.test("the most urgent essential is bought when only one fits", () => {
  const plan = planRestock([
    { id: "later", price: 40, tier: "essential", daysLeft: 5 },
    { id: "sooner", price: 30, tier: "essential", daysLeft: 1 },
  ], 30);

  assertEquals(plan.buy, ["sooner"]);
  assertEquals(plan.skip, ["later"]);
  assertEquals(plan.spent, 30);
  assertEquals(plan.essentialsShort, ["later"]);
});

Deno.test("the remaining items use knapsack rather than greedy selection", () => {
  const plan = planRestock([
    { id: "a", price: 60, tier: "important", daysLeft: 0 },
    { id: "b", price: 50, tier: "important", daysLeft: 0 },
    { id: "c", price: 50, tier: "important", daysLeft: 0 },
  ], 100);

  assertEquals(plan.buy, ["b", "c"]);
  assertEquals(plan.skip, ["a"]);
  assertEquals(plan.spent, 100);
});

Deno.test("prices with piastres are bought exactly", () => {
  const plan = planRestock([
    { id: "first", price: 33.33, tier: "important", daysLeft: 2 },
    { id: "second", price: 66.67, tier: "luxury", daysLeft: 1 },
  ], 100);

  assertEquals(plan.buy, ["first", "second"]);
  assertEquals(plan.skip, []);
  assertEquals(plan.spent, 100);
});

Deno.test("a zero budget buys nothing and shortens every essential", () => {
  const plan = planRestock([
    { id: "essential", price: 10, tier: "essential", daysLeft: 0 },
    { id: "important", price: 20, tier: "important", daysLeft: 0 },
    { id: "luxury", price: 30, tier: "luxury", daysLeft: 0 },
  ], 0);

  assertEquals(plan.buy, []);
  assertEquals(plan.skip, ["essential", "important", "luxury"]);
  assertEquals(plan.spent, 0);
  assertEquals(plan.essentialsShort, ["essential"]);
});

Deno.test("spent never exceeds the budget", () => {
  const cases: Array<{ items: RestockItem[]; budget: number }> = [
    {
      budget: 60,
      items: [
        { id: "essential", price: 30, tier: "essential", daysLeft: 1 },
        { id: "important", price: 50, tier: "important", daysLeft: 0 },
        { id: "luxury", price: 40, tier: "luxury", daysLeft: 0 },
      ],
    },
    {
      budget: 50,
      items: [
        { id: "essential", price: 20, tier: "essential", daysLeft: 4 },
        { id: "important", price: 30, tier: "important", daysLeft: 2 },
      ],
    },
    {
      budget: 75,
      items: [
        { id: "essential", price: 25, tier: "essential", daysLeft: 2 },
        { id: "important", price: 30, tier: "important", daysLeft: 0 },
        { id: "luxury", price: 20, tier: "luxury", daysLeft: 0 },
      ],
    },
  ];

  for (const { items, budget } of cases) {
    const plan = planRestock(items, budget);
    assertEquals(plan.spent <= budget, true);
  }
});

Deno.test("urgency falls as days remaining increase", () => {
  assertEquals(urgency(0), 1);
  assertEquals(urgency(3), 0.25);
});

Deno.test("invalid prices days budgets and duplicate ids are rejected", () => {
  assertThrows(
    () => planRestock([{ id: "invalid", price: 0, tier: "essential", daysLeft: 0 }], 10),
    RangeError,
  );
  assertThrows(
    () => planRestock([{ id: "invalid", price: 10, tier: "essential", daysLeft: -1 }], 10),
    RangeError,
  );
  assertThrows(() => planRestock([], Number.NaN), RangeError);
  assertThrows(
    () => planRestock([
      { id: "duplicate", price: 10, tier: "essential", daysLeft: 0 },
      { id: "duplicate", price: 20, tier: "important", daysLeft: 0 },
    ], 30),
    RangeError,
  );
});

Deno.test("among essentials the one running out sooner wins, whatever the input order", () => {
  const plan = planRestock([
    { id: "later", price: 50, tier: "essential", daysLeft: 5 },
    { id: "sooner", price: 50, tier: "essential", daysLeft: 1 },
  ], 50);
  assertEquals(plan.buy, ["sooner"]);
  assertEquals(plan.essentialsShort, ["later"]);
});

Deno.test("equal value: the earlier item keeps the slot (deterministic)", () => {
  const plan = planRestock([
    { id: "first", price: 50, tier: "important", daysLeft: 0 },
    { id: "second", price: 50, tier: "important", daysLeft: 0 },
  ], 50);
  assertEquals(plan.buy, ["first"]);
});

Deno.test("money is rounded to the nearest piastre, never down: 0.29 does not fit in 0.28", () => {
  // 0.29 * 100 = 28.999999999999996 in floating point; flooring it would 'fit' a 0.28 budget.
  const plan = planRestock([{ id: "x", price: 0.29, tier: "essential", daysLeft: 0 }], 0.28);
  assertEquals(plan.buy, []);
  assertEquals(plan.essentialsShort, ["x"]);
});
