// «هشتري موبايل بـ٢٠ ألف» على متاح ٦ آلاف: الحساب بيتعمل بالكود، مش بيتساب للموديل.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { plannedPurchase, purchaseCheckBlock } from "./persona.ts";

Deno.test("a purchase still to come, with its amount — not one already made", () => {
  assertEquals(plannedPurchase("هشتري موبايل جديد بـ20 ألف جنيه النهارده كاش"), 20000);
  assertEquals(plannedPurchase("ناوي أجيب تلاجة بـ١٥ ألف"), 15000);
  assertEquals(plannedPurchase("عايز اشتري جزمة بـ 1,200"), 1200);
  assertEquals(plannedPurchase("اشتريت موبايل بـ20 ألف"), null);
  assertEquals(plannedPurchase("صرفت 50 جنيه قهوة"), null);
  assertEquals(plannedPurchase("هشتري حاجات للبيت"), null);
});

Deno.test("over the available: the gap and the times, ready to be said", () => {
  const b = purchaseCheckBlock("هشتري موبايل جديد بـ20 ألف جنيه النهارده كاش", 6000, "EGP");
  assert(b.includes("20,000") && b.includes("6,000") && b.includes("14,000"), b);
  assert(b.includes("3.3 أضعاف"), b);
});

Deno.test("half the available or more says the share; a small one or an unknown budget says nothing", () => {
  assert(purchaseCheckBlock("هشتري تلاجة بـ4000", 6000, "EGP").includes("67٪"));
  assertEquals(purchaseCheckBlock("هشتري شاحن بـ200", 6000, "EGP"), "");
  assertEquals(purchaseCheckBlock("هشتري موبايل بـ20 ألف", null, "EGP"), "");
  assert(purchaseCheckBlock("هشتري موبايل بـ20 ألف", 0, "EGP").includes("خلصان"));
});
