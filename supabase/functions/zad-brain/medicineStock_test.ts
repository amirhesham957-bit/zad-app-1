import { assertEquals } from "jsr:@std/assert@1";
import { medicineDaysLeft, medicineLow } from "./medicineStock.ts";

Deno.test("days left counts units per dose, not just doses", () => {
  assertEquals(medicineDaysLeft({ remaining_quantity: 20, daily_dose_count: 2 }), 10);
  assertEquals(medicineDaysLeft({ remaining_quantity: 20, daily_dose_count: 2, units_per_dose: 2 }), 5);
  assertEquals(medicineDaysLeft({ remaining_quantity: 7, daily_dose_count: 2 }), 3); // 3.5 → whole days
});

Deno.test("no stock recorded or no schedule → no days figure", () => {
  assertEquals(medicineDaysLeft({ remaining_quantity: null, daily_dose_count: 2 }), null);
  assertEquals(medicineDaysLeft({ remaining_quantity: 10, daily_dose_count: null }), null);
  assertEquals(medicineDaysLeft({ remaining_quantity: 10, daily_dose_count: 0 }), null);
});

Deno.test("low at the reorder point: 5 days of use, inclusive", () => {
  assertEquals(medicineLow({ remaining_quantity: 10, daily_dose_count: 2 }), true); // exactly 5 days
  assertEquals(medicineLow({ remaining_quantity: 11, daily_dose_count: 2 }), false);
  // Two pills a dose: 18 pills is only 4.5 days.
  assertEquals(medicineLow({ remaining_quantity: 18, daily_dose_count: 2, units_per_dose: 2 }), true);
  assertEquals(medicineLow({ remaining_quantity: 18, daily_dose_count: 2, units_per_dose: 1 }), false);
});

Deno.test("run out is low even without a schedule; no stock recorded is never low", () => {
  assertEquals(medicineLow({ remaining_quantity: 0, daily_dose_count: null }), true);
  assertEquals(medicineLow({ remaining_quantity: 3, daily_dose_count: null }), false);
  assertEquals(medicineLow({ remaining_quantity: null, daily_dose_count: 3 }), false);
});

Deno.test("odd units fall back to one per dose instead of throwing", () => {
  assertEquals(medicineDaysLeft({ remaining_quantity: 6, daily_dose_count: 3, units_per_dose: 0 }), 2);
  assertEquals(medicineLow({ remaining_quantity: -2, daily_dose_count: 1 }), true);
});
