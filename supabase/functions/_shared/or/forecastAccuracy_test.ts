import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { accuracyReport, type ForecastOutcome, mae, wape, bias, coverage } from "./forecastAccuracy.ts";

Deno.test("rows (predicted, actual) = (8,10), (5,5), (4,1): mae 1.6667, wape 0.3125, bias 0.0625, accuracyPct 69, n 3, coverage null", () => {
  const rows: ForecastOutcome[] = [{ predicted: 8, actual: 10 }, { predicted: 5, actual: 5 }, { predicted: 4, actual: 1 }];
  const report = accuracyReport(rows);
  assertEquals(report.mae, 1.6667);
  assertEquals(report.wape, 0.3125);
  assertEquals(report.bias, 0.0625);
  assertEquals(report.accuracyPct, 69);
  assertEquals(report.n, 3);
  assertEquals(report.coverage, null);
});

Deno.test("Empty rows → n 0 and every metric null", () => {
  const report = accuracyReport([]);
  assertEquals(report.n, 0);
  assertEquals(report.mae, null);
  assertEquals(report.wape, null);
  assertEquals(report.bias, null);
  assertEquals(report.coverage, null);
  assertEquals(report.accuracyPct, null);
});

Deno.test("All actuals 0 → wape, bias, accuracyPct null; mae still computed", () => {
  const rows: ForecastOutcome[] = [{ predicted: 1, actual: 0 }, { predicted: 2, actual: 0 }];
  const report = accuracyReport(rows);
  assertEquals(report.mae, 1.5);
  assertEquals(report.wape, null);
  assertEquals(report.bias, null);
  assertEquals(report.accuracyPct, null);
});

Deno.test("Coverage: 4 rows with bands, 3 inside (edges inclusive) → 0.75; rows without a band are ignored", () => {
  const rows: ForecastOutcome[] = [
    { predicted: 5, actual: 5, low: 4, high: 6 },
    { predicted: 5, actual: 4, low: 4, high: 6 },
    { predicted: 5, actual: 6, low: 4, high: 6 },
    { predicted: 5, actual: 7, low: 4, high: 6 },
    { predicted: 5, actual: 5 }, // No band
  ];
  assertEquals(coverage(rows), 0.75);
});

Deno.test("A wape above 1 gives accuracyPct 0, never negative", () => {
  const rows: ForecastOutcome[] = [{ predicted: 100, actual: 1 }];
  const report = accuracyReport(rows);
  assertEquals(report.accuracyPct, 0);
});

Deno.test("Under-forecast gives negative bias", () => {
  const rows: ForecastOutcome[] = [{ predicted: 5, actual: 10 }];
  const report = accuracyReport(rows);
  assertEquals(report.bias, -0.5);
});

Deno.test("NaN, Infinity and a negative actual each throw RangeError", () => {
  assertThrows(() => mae([{ predicted: NaN, actual: 10 }]), RangeError);
  assertThrows(() => wape([{ predicted: Infinity, actual: 10 }]), RangeError);
  assertThrows(() => bias([{ predicted: 10, actual: -1 }]), RangeError);
  assertThrows(() => coverage([{ predicted: 1, actual: 1, low: -1, high: 2 }]), RangeError);
});
