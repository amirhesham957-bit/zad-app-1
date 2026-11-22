import { assertEquals } from "jsr:@std/assert@1";
import { filterOffersFor, isMinor, type Offer } from "./minorGuard.ts";

const offers: Offer[] = [
  { id: "a", kind: "targeted_ad" },
  { id: "b", kind: "affiliate" },
  { id: "c", kind: "plain" },
];

Deno.test("وضع الأطفال مفعّل ⇒ قاصر", () => assertEquals(isMinor({ isChild: true }), true));
Deno.test("مش مفعّل ⇒ بالغ، وغياب المعلومة بالغ كمان", () => {
  assertEquals(isMinor({ isChild: false }), false);
  assertEquals(isMinor({}), false);
});
Deno.test("وضع الأطفال: بيتشال الموجّه والعمولة", () => {
  assertEquals(filterOffersFor({ isChild: true }, offers).map((o) => o.id), ["c"]);
});
Deno.test("بالغ: الكل زي ما هو", () => {
  assertEquals(filterOffersFor({}, offers).map((o) => o.id), ["a", "b", "c"]);
});
