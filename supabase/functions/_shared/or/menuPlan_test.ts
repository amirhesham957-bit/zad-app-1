import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import { arrangeDays, type Dish, planMenu } from "./menuPlan.ts";

const three: Dish[] = [
  { id: "a", cost: 300, taste: 9 },
  { id: "b", cost: 100, taste: 8 },
  { id: "c", cost: 50, taste: 5 },
];

Deno.test("budget binds: the 100 + 50 pair", async () => {
  const p = await planMenu(three, { days: 2, budget: 160 });
  assertEquals([...p.days].sort(), ["b", "c"]);
  assertEquals(p.spent, 150);
  assertEquals(p.feasible, true);
});

Deno.test("loose budget: the two tastiest", async () => {
  const p = await planMenu(three, { days: 2, budget: 1000 });
  assertEquals([...p.days].sort(), ["a", "b"]);
  assertEquals(p.totalTaste, 17);
});

Deno.test("maxRepeat 2: the great cheap dish twice, never back to back", async () => {
  const p = await planMenu([{ id: "great", cost: 10, taste: 10 }, { id: "ok", cost: 20, taste: 4 }], { days: 3, budget: 100, maxRepeat: 2 });
  assertEquals(p.days.filter((d) => d === "great").length, 2);
  for (let i = 1; i < p.days.length; i++) assert(p.days[i] !== p.days[i - 1]);
});

Deno.test("not enough budget: nulls fill the rest, infeasible, spent within budget", async () => {
  const p = await planMenu(three, { days: 3, budget: 160 });
  assertEquals(p.feasible, false);
  assert(p.spent <= 160);
  assertEquals(p.days.filter((d) => d === null).length, 1);
});

Deno.test("nothing fits at all", async () => {
  const p = await planMenu(three, { days: 2, budget: 10 });
  assertEquals(p.days, [null, null]);
  assertEquals(p.spent, 0);
  assertEquals(p.feasible, false);
});

Deno.test("no dishes", async () => {
  assertEquals((await planMenu([], { days: 3, budget: 100 })).feasible, false);
});

Deno.test("minDistinctTags forces a second tag", async () => {
  const dishes: Dish[] = [
    { id: "m1", cost: 10, taste: 9, tags: ["meat"] },
    { id: "m2", cost: 10, taste: 8, tags: ["meat"] },
    { id: "v1", cost: 10, taste: 3, tags: ["veg"] },
  ];
  const free = await planMenu(dishes, { days: 2, budget: 100 });
  assertEquals([...free.days].sort(), ["m1", "m2"]);
  const forced = await planMenu(dishes, { days: 2, budget: 100, minDistinctTags: 2 });
  assertEquals([...forced.days].sort(), ["m1", "v1"]);
  assertEquals(forced.feasible, true);
});

Deno.test("impossible tag rule is ignored and flagged", async () => {
  const p = await planMenu([{ id: "m1", cost: 10, taste: 9, tags: ["meat"] }], { days: 1, budget: 100, minDistinctTags: 2 });
  assertEquals(p.days, ["m1"]);
  assertEquals(p.feasible, false);
});

Deno.test("equal taste: the cheaper dish wins", async () => {
  const p = await planMenu([{ id: "dear", cost: 90, taste: 7 }, { id: "cheap", cost: 40, taste: 7 }], { days: 1, budget: 100 });
  assertEquals(p.days, ["cheap"]);
});

Deno.test("exact against brute force on seeded random dishes", async () => {
  let seed = 12345;
  const rnd = () => (seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648;
  for (let round = 0; round < 6; round++) {
    const dishes: Dish[] = Array.from({ length: 8 }, (_, i) => ({
      id: `d${i}`, cost: Math.round(rnd() * 90 + 10), taste: Math.round(rnd() * 10),
    }));
    const budget = 150;
    let best = -1;
    const n = dishes.length;
    for (let a = 0; a < n; a++) for (let b = a + 1; b < n; b++) for (let c = b + 1; c < n; c++) {
      if (dishes[a].cost + dishes[b].cost + dishes[c].cost <= budget) best = Math.max(best, dishes[a].taste + dishes[b].taste + dishes[c].taste);
    }
    const p = await planMenu(dishes, { days: 3, budget });
    if (best < 0) assertEquals(p.feasible, false);
    else {
      assertEquals(p.feasible, true);
      assertEquals(p.totalTaste, best);
      assert(p.spent <= budget);
    }
  }
});

Deno.test("arrangeDays spreads repeats", () => {
  const order = arrangeDays(new Map([["x", 2], ["y", 1]]), new Map([["x", 5], ["y", 9]]));
  assertEquals(order, ["x", "y", "x"]);
});

Deno.test("validation errors throw RangeError", async () => {
  await assertRejects(() => planMenu([{ id: "a", cost: 1, taste: 5 }, { id: "a", cost: 1, taste: 5 }], { days: 1, budget: 5 }), RangeError);
  await assertRejects(() => planMenu([{ id: "a", cost: -1, taste: 5 }], { days: 1, budget: 5 }), RangeError);
  await assertRejects(() => planMenu([{ id: "a", cost: 1, taste: 11 }], { days: 1, budget: 5 }), RangeError);
  await assertRejects(() => planMenu([{ id: "a", cost: 1, taste: 5 }], { days: 0, budget: 5 }), RangeError);
  await assertRejects(() => planMenu([{ id: "a", cost: 1, taste: 5 }], { days: 15, budget: 5 }), RangeError);
  await assertRejects(() => planMenu([{ id: "a", cost: 1, taste: 5 }], { days: 1, budget: NaN }), RangeError);
});
