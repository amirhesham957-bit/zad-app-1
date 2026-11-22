import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { levelCorrection, type Tap, tapCorrection } from "./rateCorrection.ts";

const DAY_MS = 24 * 60 * 60 * 1000;
const f = { rate: 1, low: 0.5, high: 1.5, basis: "blended" as const, days: 6 };

Deno.test("faster then slower restores the rate and scales the band", () => {
  const faster = tapCorrection(f, "faster");
  assertEquals(faster, { rate: 1.3, low: 0.65, high: 1.95, basis: "blended", days: 6 });
  assertEquals(tapCorrection(faster, "slower"), f);
});

Deno.test("tapCorrection rejects an unknown tap and a negative rate", () => {
  assertThrows(() => tapCorrection(f, "sideways" as Tap), RangeError);
  assertThrows(() => tapCorrection({ ...f, rate: -1 }, "faster"), RangeError);
});

Deno.test("levelCorrection blends an observed level and preserves proportional bands", () => {
  assertEquals(levelCorrection(f, 10, 0, 4, 2 * DAY_MS), {
    rate: 1.5,
    low: 0.75,
    high: 2.25,
    basis: "blended",
    days: 7,
  });
});

Deno.test("levelCorrection leaves recent observations and restocks unchanged", () => {
  assertEquals(levelCorrection(f, 10, 0, 9, 30 * 60 * 1000), f);
  assertEquals(levelCorrection(f, 10, 0, 11, 2 * DAY_MS), f);
});

Deno.test("levelCorrection marks day fourteen as observed", () => {
  const corrected = levelCorrection({ ...f, days: 13 }, 10, 0, 4, 2 * DAY_MS);
  assertEquals(corrected.days, 14);
  assertEquals(corrected.basis, "observed");
});

Deno.test("levelCorrection uses half and one-and-a-half bands for a zero rate", () => {
  assertEquals(levelCorrection({ ...f, rate: 0, low: 0, high: 0 }, 10, 0, 4, 2 * DAY_MS), {
    rate: 0.75,
    low: 0.375,
    high: 1.125,
    basis: "blended",
    days: 7,
  });
});

Deno.test("levelCorrection rejects invalid quantities and backwards timestamps", () => {
  assertThrows(() => levelCorrection(f, -1, 0, 4, DAY_MS), RangeError);
  assertThrows(() => levelCorrection(f, 10, 0, NaN, DAY_MS), RangeError);
  assertThrows(() => levelCorrection(f, 10, DAY_MS, 4, 0), RangeError);
});
