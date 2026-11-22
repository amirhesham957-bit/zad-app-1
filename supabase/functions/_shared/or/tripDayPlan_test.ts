import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";
import { type DayPlanInput, type Place, planTripDay } from "./tripDayPlan.ts";

const start = { lat: 30.0, lng: 31.0 };
// حوالي ١٫١ كم لكل ٠٫٠١ درجة عرض
const at = (id: string, dLat: number, value: number, visitMin: number, cost: number): Place => ({
  id,
  value,
  visitMin,
  cost,
  lat: 30.0 + dLat,
  lng: 31.0,
});

const base = (places: Place[], over: Partial<DayPlanInput> = {}): DayPlanInput => ({
  places,
  start,
  availableMin: 240,
  budget: 500,
  speedKmh: 30,
  ...over,
});

Deno.test("empty input gives empty plan", () => {
  assertEquals(planTripDay(base([])), { ids: [], totalValue: 0, minutes: 0, cost: 0 });
});

Deno.test("zero budget skips paid places, keeps free ones", () => {
  const p = planTripDay(base([at("paid", 0.01, 10, 30, 50), at("free", 0.02, 3, 30, 0)], { budget: 0 }));
  assertEquals(p.ids, ["free"]);
  assertEquals(p.cost, 0);
});

Deno.test("zero time fits nothing with a visit", () => {
  const p = planTripDay(base([at("a", 0.01, 10, 30, 0)], { availableMin: 0 }));
  assertEquals(p.ids, []);
});

Deno.test("both limits respected on a bigger set", () => {
  const places = Array.from({ length: 12 }, (_, i) => at(`p${i}`, 0.005 * (i + 1), 1 + (i % 5), 20 + (i % 4) * 10, 20 + (i % 3) * 30));
  const p = planTripDay(base(places, { availableMin: 150, budget: 120 }));
  assert(p.minutes <= 150 + 1e-6, `minutes ${p.minutes}`);
  assert(p.cost <= 120, `cost ${p.cost}`);
  assert(p.ids.length > 0);
  assertEquals(new Set(p.ids).size, p.ids.length);
});

Deno.test("picks the higher-value set when only one fits the budget", () => {
  const p = planTripDay(base([at("low", 0.01, 2, 30, 100), at("high", 0.01, 9, 30, 100)], { budget: 100 }));
  assertEquals(p.ids, ["high"]);
  assertEquals(p.totalValue, 9);
});

Deno.test("time limit drops the far low-value place", () => {
  const p = planTripDay(base([at("near", 0.01, 5, 60, 0), at("far", 0.5, 6, 60, 0)], { availableMin: 100 }));
  assertEquals(p.ids, ["near"]);
});

Deno.test("2-opt untangles the route order", () => {
  const p = planTripDay(base([at("c", 0.03, 1, 10, 0), at("a", 0.01, 1, 10, 0), at("b", 0.02, 1, 10, 0)]));
  assertEquals(p.ids, ["a", "b", "c"]);
});

Deno.test("deterministic regardless of input order", () => {
  const places = Array.from({ length: 8 }, (_, i) => at(`p${i}`, 0.004 * (i + 1), 1 + (i % 3), 25, 10));
  const a = planTripDay(base(places, { availableMin: 120 }));
  const b = planTripDay(base([...places].reverse(), { availableMin: 120 }));
  assertEquals(a, b);
  assertEquals(planTripDay(base(places, { availableMin: 120 })), a);
});

Deno.test("bad input throws", () => {
  assertThrows(() => planTripDay(base([], { speedKmh: 0 })), RangeError);
  assertThrows(() => planTripDay(base([], { budget: -1 })), RangeError);
  assertThrows(() => planTripDay(base([at("a", 0, 1, 1, 0), at("a", 0, 1, 1, 0)])), RangeError);
});
