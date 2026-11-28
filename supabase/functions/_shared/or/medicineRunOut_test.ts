import { assertEquals } from "jsr:@std/assert@1";
import { medicineRunOut, runOutWhen } from "./medicineRunOut.ts";

Deno.test("doses x units: 20 tablets, 2/day, 2 units -> 5 days", () => {
  const r = medicineRunOut({ remaining_quantity: 20, daily_dose_count: 2, units_per_dose: 2 }, "2026-11-28");
  assertEquals(r?.daysLeft, 5);
  assertEquals(r?.runOutDate, "2026-12-03");
  assertEquals(r?.dailyUnits, 4);
});
Deno.test("units default to 1, floors partial day", () => {
  assertEquals(medicineRunOut({ remaining_quantity: 7, daily_dose_count: 2 }, "2026-11-28")?.daysLeft, 3);
});
Deno.test("empty stock -> today", () => {
  const r = medicineRunOut({ remaining_quantity: 0, daily_dose_count: 1 }, "2026-11-28");
  assertEquals(r?.runOutDate, "2026-11-28");
  assertEquals(runOutWhen({ remaining_quantity: 0, daily_dose_count: 1 }, "2026-11-28").startsWith("النهارده"), true);
});
Deno.test("no schedule / no stock / bad input -> null, never guessed", () => {
  assertEquals(medicineRunOut({ remaining_quantity: 10, daily_dose_count: 0 }, "2026-11-28"), null);
  assertEquals(medicineRunOut({ remaining_quantity: null, daily_dose_count: 2 }, "2026-11-28"), null);
  assertEquals(medicineRunOut({ remaining_quantity: 10, daily_dose_count: 2 }, "bad"), null);
  assertEquals(runOutWhen({ remaining_quantity: null, daily_dose_count: 2 }, "2026-11-28"), "قريب");
});
Deno.test("month boundary", () => {
  assertEquals(medicineRunOut({ remaining_quantity: 6, daily_dose_count: 1 }, "2026-12-29")?.runOutDate, "2027-01-04");
});
