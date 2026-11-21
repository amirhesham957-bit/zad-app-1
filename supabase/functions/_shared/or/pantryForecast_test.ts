import { assertEquals } from "jsr:@std/assert@1";
import { dailyDemandFromLevels, pantryForecast, PRIOR_WEIGHT_DAYS } from "./pantryForecast.ts";

const day = (d: number, h = 12) => new Date(Date.UTC(2026, 10, d, h)).toISOString();
const NOW = Date.UTC(2026, 10, 10, 18);

Deno.test("a drop inside one day lands on that day; a restock adds nothing", () => {
  const s = dailyDemandFromLevels([
    { qty: 4, at: day(8, 8) },
    { qty: 2, at: day(8, 20) },
    { qty: 6, at: day(9, 10) }, // اتشرى
    { qty: 5, at: day(10, 10) },
  ], NOW);
  // الأيام ٨ و٩ و١٠: ٢ يوم ٨، وصفر يوم ٩ (شرا)، والواحد بين ٩ و١٠ بيتقسم على الوقت (١٤ ساعة في ٩ و١٠ في ١٠).
  assertEquals(s.length, 3);
  assertEquals(s[0], 2);
  assertEquals(Math.round((s[1] + s[2]) * 1e6) / 1e6, 1);
  assertEquals(Math.round(s[1] * 24 * 1e3) / 1e3, 14);
});

Deno.test("readings under an hour apart are a correction, not consumption", () => {
  assertEquals(dailyDemandFromLevels([{ qty: 5, at: day(10, 10) }, { qty: 1, at: day(10, 10).replace("10:00", "10:20") }], NOW), [0]);
});

Deno.test("bad and future readings are dropped; no readings = empty series", () => {
  assertEquals(dailyDemandFromLevels([], NOW), []);
  assertEquals(dailyDemandFromLevels([{ qty: -1, at: day(9) }, { qty: 3, at: "nope" }, { qty: 1, at: day(20) }], NOW), []);
});

Deno.test("history is capped to the last maxDays", () => {
  const s = dailyDemandFromLevels([{ qty: 10, at: day(1) }, { qty: 0, at: day(10, 6) }], NOW, 3);
  assertEquals(s.length, 3);
});

Deno.test("no readings: the household prior with a band, basis prior", () => {
  const f = pantryForecast(3, [], 0.5, NOW);
  assertEquals(f.basis, "prior");
  assertEquals(f.rate, 0.5);
  assertEquals(f.daysLeft, 6);
  assertEquals(f.daysLeftLow, 4); // 3 / 0.75
  assertEquals(f.daysLeftHigh, 12); // 3 / 0.25
});

Deno.test("observed drinking pulls the rate off the prior, weighted by days", () => {
  // ٨ أيام كل يوم بينزل واحد ⇒ معدل البيت قريب من ١، والمبدئي ٠٫٢ بوزن ٧ أيام.
  const readings = Array.from({ length: 9 }, (_, i) => ({ qty: 20 - i, at: day(2 + i, 9) }));
  const f = pantryForecast(10, readings, 0.2, NOW);
  assertEquals(f.basis, "blended");
  assertEquals(f.rate > 0.2 && f.rate < 1, true);
  assertEquals(f.daysLeftLow! <= f.daysLeft! && f.daysLeft! <= f.daysLeftHigh!, true);
  assertEquals(PRIOR_WEIGHT_DAYS, 7);
});

Deno.test("nothing known (no prior, no drops): no days left, not zero", () => {
  const f = pantryForecast(2, [], 0, NOW);
  assertEquals(f.rate, 0);
  assertEquals(f.daysLeft, null);
  assertEquals(f.daysLeftHigh, null);
});
