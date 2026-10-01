// متجدد ولا كورس (قرار المالك ٢٠٢٦-١٠-٠١): الدوا المتجدد بس بينزل قايمة البقالة لوحده.
import { assertEquals } from "jsr:@std/assert@1";
import { pharmacyIsRecurring } from "./shared.ts";
import { freshContext, validateUpdatePharmacyItem } from "./validators.ts";

Deno.test("pharmacyIsRecurring: what the model said wins, then the category, else unknown", () => {
  assertEquals(pharmacyIsRecurring({ is_recurring: true, category: "مضاد حيوي" }), true);
  assertEquals(pharmacyIsRecurring({ is_recurring: false, category: "مزمن" }), false);
  assertEquals(pharmacyIsRecurring({ category: "مزمن" }), true);
  assertEquals(pharmacyIsRecurring({ category: "مضاد حيوي" }), false);
  assertEquals(pharmacyIsRecurring({ category: "عام" }), null);
  assertEquals(pharmacyIsRecurring({ is_recurring: "yes" }), null);
});

Deno.test("«ده دوا مزمن» alone is an update the validator lets through", async () => {
  const ctx = freshContext("u");
  assertEquals((await validateUpdatePharmacyItem({ name: "كونكور", is_recurring: true }, {}, ctx)).ok, true);
  assertEquals((await validateUpdatePharmacyItem({ name: "كونكور" }, {}, ctx)).ok, false);
});
