import { assertEquals } from "jsr:@std/assert@1";
import { purchaseQuantity } from "./purchaseQuantity.ts";

Deno.test("half a kilo of rice stays half a kilo; pills stay whole", () => {
  assertEquals(purchaseQuantity(0.5, "pantry"), 0.5);
  assertEquals(purchaseQuantity("1.25", "pantry"), 1.25);
  assertEquals(purchaseQuantity(10, "pantry"), 10);
  assertEquals(purchaseQuantity(0.33333, "pantry"), 0.333);
  assertEquals(purchaseQuantity(2.4, "pharmacy"), 2);
  assertEquals(purchaseQuantity(0.4, "pharmacy"), 1);
});

Deno.test("nothing readable is one", () => {
  for (const raw of [null, undefined, "", "x", 0, -2, Number.NaN]) {
    assertEquals(purchaseQuantity(raw, "pantry"), 1);
  }
  assertEquals(purchaseQuantity(1e9, "pantry"), 10000);
});
