import { assertEquals } from "jsr:@std/assert@1";
import {
  accuracyReport,
  bias,
  coverage,
  type ForecastOutcome,
  isEvidenceWeek,
  mae,
  type SettledWeek,
  wape,
  weeklySpendSummary,
} from "./forecastAccuracy.ts";

const WEEKS: SettledWeek[] = [
  { predicted: 100, actual: 80, recorded: 5 },
  { predicted: 100, actual: 125, recorded: 4 },
  { predicted: 90, actual: 0, recorded: 0 },
  { predicted: 50, actual: 10, recorded: 1 },
];

Deno.test("weeklySpendSummary counts settled, evidence, and thin weeks", () => {
  const summary = weeklySpendSummary(WEEKS);
  assertEquals(summary.settled, 4);
  assertEquals(summary.evidence, 2);
  assertEquals(summary.thin, 2);
});

Deno.test("weeklySpendSummary matches SQL wape and bias over evidence weeks", () => {
  const summary = weeklySpendSummary(WEEKS);
  assertEquals(summary.wape, 0.220);
  assertEquals(summary.bias, -0.024);
});

Deno.test("weeklySpendSummary returns null metrics when every week is thin", () => {
  const summary = weeklySpendSummary(WEEKS.slice(2));
  assertEquals(summary, {
    settled: 2,
    evidence: 0,
    thin: 2,
    wape: null,
    bias: null,
  });
});

Deno.test("isEvidenceWeek requires three recordings and a positive actual", () => {
  assertEquals(isEvidenceWeek({ predicted: 10, actual: 1, recorded: 3 }), true);
  assertEquals(isEvidenceWeek({ predicted: 10, actual: 1, recorded: 2 }), false);
  assertEquals(isEvidenceWeek({ predicted: 10, actual: 0, recorded: 3 }), false);
});

Deno.test("existing accuracy exports preserve the known forecastAccuracy_test case", () => {
  const rows: ForecastOutcome[] = [
    { predicted: 8, actual: 10 },
    { predicted: 5, actual: 5 },
    { predicted: 4, actual: 1 },
  ];
  assertEquals(mae(rows), 5 / 3);
  assertEquals(wape(rows), 0.3125);
  assertEquals(bias(rows), 0.0625);
  assertEquals(coverage(rows), null);
  assertEquals(accuracyReport(rows), {
    n: 3,
    mae: 1.6667,
    wape: 0.3125,
    bias: 0.0625,
    coverage: null,
    accuracyPct: 69,
  });
});
