import { assertEquals } from "jsr:@std/assert@1";
import {
  type ModelOutcome,
  TUNE_MAX_SCALE,
  tuneHouseholdCoefficients,
  weeklyModelReport,
} from "./modelAccuracy.ts";

const row = (model: string, h: string, w: string, predicted: number, actual: number): ModelOutcome => ({
  model, householdId: h, weekStart: w, predicted, actual,
});

Deno.test("weekly report groups by week and model, sorted", () => {
  const rep = weeklyModelReport([
    row("tsb", "a", "2026-11-15", 8, 10),
    row("tsb", "b", "2026-11-15", 5, 5),
    row("tsb", "a", "2026-11-15", 4, 1),
    row("safeSpend", "a", "2026-11-08", 10, 10),
  ]);
  assertEquals(rep.map((r) => `${r.weekStart}/${r.model}`), ["2026-11-08/safeSpend", "2026-11-15/tsb"]);
  assertEquals(rep[1].n, 3);
  assertEquals(rep[1].wape, 0.3125);
  assertEquals(rep[1].accuracyPct, 69);
  assertEquals(rep[0].accuracyPct, 100);
});

Deno.test("weekly report empty input", () => {
  assertEquals(weeklyModelReport([]), []);
});

Deno.test("tuning: under TUNE_MIN_N rows leaves scale 1", () => {
  const rows = Array.from({ length: 7 }, () => row("tsb", "a", "w", 20, 10));
  const [t] = tuneHouseholdCoefficients(rows);
  assertEquals(t.scale, 1);
  assertEquals(t.tuned, false);
  assertEquals(t.n, 7);
});

Deno.test("tuning: over-predicting household is scaled down, shrunk by n", () => {
  // bias = +0.25 -> ideal 0.8; n=20 -> weight 0.5 -> scale 0.9
  const rows = Array.from({ length: 20 }, () => row("tsb", "a", "w", 12.5, 10));
  const [t] = tuneHouseholdCoefficients(rows);
  assertEquals(t.scale, 0.9);
  assertEquals(t.tuned, true);
});

Deno.test("tuning: full strength at 40 rows, clamped to bounds", () => {
  const over = Array.from({ length: 40 }, () => row("tsb", "a", "w", 100, 10));
  assertEquals(tuneHouseholdCoefficients(over)[0].scale, 0.7);
  const under = Array.from({ length: 40 }, () => row("tsb", "b", "w", 1, 10));
  assertEquals(tuneHouseholdCoefficients(under)[0].scale, TUNE_MAX_SCALE);
});

Deno.test("tuning: unbiased or zero-actual stays 1; households and models are independent", () => {
  const rows = [
    ...Array.from({ length: 10 }, () => row("tsb", "a", "w", 10, 10)),
    ...Array.from({ length: 10 }, () => row("tsb", "b", "w", 5, 0)),
    ...Array.from({ length: 10 }, () => row("safeSpend", "a", "w", 20, 10)),
  ];
  const t = tuneHouseholdCoefficients(rows);
  // safeSpend/a: n=10 -> weight 0.25, ideal 0.5 -> 0.875
  assertEquals(t.map((x) => `${x.model}/${x.householdId}:${x.scale}`), [
    "safeSpend/a:0.875",
    "tsb/a:1",
    "tsb/b:1",
  ]);
});
