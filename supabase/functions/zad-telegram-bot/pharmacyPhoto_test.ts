import { assertEquals } from "jsr:@std/assert@1";
import { NEW_MEDICINES_MAX, splitPhotoMedicines } from "./pharmacyPhoto.ts";

Deno.test("a medicine already in the pharmacy is topped up; a new one waits for the button", () => {
  const { known, fresh } = splitPhotoMedicines(
    [
      { name: " Panadol Extra ", quantity: 2, unit: "علبة" },
      { name: "أوجمنتين 1جم", quantity: 1.4, unit: null },
      { name: "", quantity: 1 },
      { name: "أوجمنتين 1جم", quantity: 1 },
    ],
    ["panadol extra"],
  );
  assertEquals(known, [{ name: "Panadol Extra", quantity: 2, unit: "علبة" }]);
  assertEquals(fresh, [{ name: "أوجمنتين 1جم", quantity: 1, unit: "قرص" }]);
});

Deno.test("«known» is the brain's own rule — a near spelling is new, so it is confirmed", () => {
  const { known, fresh } = splitPhotoMedicines([{ name: "اوجمنتين 1جم", quantity: 1 }], ["أوجمنتين 1جم"]);
  assertEquals([known.length, fresh.length], [0, 1]);
});

Deno.test("five new medicines at most from one photo", () => {
  const items = Array.from({ length: 8 }, (_, i) => ({ name: `دوا ${i}`, quantity: 1 }));
  assertEquals(splitPhotoMedicines(items, []).fresh.length, NEW_MEDICINES_MAX);
});
