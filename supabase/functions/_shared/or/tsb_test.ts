import { assertAlmostEquals, assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  daysUntilEmpty,
  forecastItem,
  shrinkRate,
  tsbFit,
  tsbRate,
} from "./tsb.ts";

Deno.test("tsbRate for constant daily demand", () => {
  const state = tsbFit(Array(30).fill(2));
  assertEquals(tsbRate(state), 2);
});

Deno.test("tsbRate for periodic intermittent demand", () => {
  const series = Array(10).fill([0, 0, 0, 6]).flat();
  const rate = tsbRate(tsbFit(series));
  assertAlmostEquals(rate, 1.5, 0.4);
});

Deno.test("obsolescence decay when demand drops to zero", () => {
  const series = [...Array(20).fill(3), ...Array(30).fill(0)];
  const rate = tsbRate(tsbFit(series));
  assertEquals(rate < 0.5, true);
});

Deno.test("forecastItem with empty input uses prior", () => {
  const fc = forecastItem([], { dailyRate: 0.5, weight: 7 });
  assertEquals(fc, {
    rate: 0.5,
    low: 0.25,
    high: 0.75,
    basis: "prior",
    days: 0,
  });
});

Deno.test("shrinkRate shrinks observed toward prior based on weight", () => {
  const prior = { dailyRate: 0.5, weight: 7 };
  assertEquals(shrinkRate(1, 0, prior), 0.5);
  assertEquals(shrinkRate(1, 7, prior), 0.75);
});

Deno.test("forecastItem basis is blended for 5 days and observed for 14 days", () => {
  const prior = { dailyRate: 0.5, weight: 7 };
  const fc5 = forecastItem(Array(5).fill(1), prior);
  assertEquals(fc5.basis, "blended");

  const fc14 = forecastItem(Array(14).fill(1), prior);
  assertEquals(fc14.basis, "observed");
});

Deno.test("confidence bounds for noisy series satisfy 0 <= low <= rate <= high", () => {
  const series = [0, 2, 0, 1, 5, 0, 0, 3, 1, 0, 4, 0, 2, 0, 1];
  const fc = forecastItem(series, { dailyRate: 1, weight: 5 });
  assertEquals(fc.low >= 0, true);
  assertEquals(fc.low <= fc.rate, true);
  assertEquals(fc.rate <= fc.high, true);
});

Deno.test("negative and NaN inputs throw RangeError", () => {
  assertThrows(() => tsbFit([-1, 2, 3]), RangeError);
  assertThrows(() => tsbFit([1, NaN, 3]), RangeError);
  assertThrows(() => tsbFit([1, Infinity, 3]), RangeError);
});

Deno.test("daysUntilEmpty calculates days or null for zero/negative rate", () => {
  assertEquals(daysUntilEmpty(10, 2), 5);
  assertEquals(daysUntilEmpty(10, 0), null);
  assertEquals(daysUntilEmpty(10, -1), null);
});
