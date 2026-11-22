import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { offerValue, rankOffers, type Offer } from "./offerValue.ts";

const o = (p: Partial<Offer> & { id: string }): Offer => ({ price: 8, usualPrice: 10, needProb: 0.5, annoyance: 0.2, ...p });

Deno.test("القيمة = توفير × احتمال − إزعاج", () => {
  assertEquals(offerValue(o({ id: "a" })), 2 * 0.5 - 0.2);
});
Deno.test("مفيش توفير: قيمة سالبة بقدر الإزعاج", () => {
  assertEquals(offerValue(o({ id: "a", price: 12 })), -0.2);
});
Deno.test("مدخلات غلط", () => {
  assertThrows(() => offerValue(o({ id: "a", needProb: 1.5 })), RangeError);
  assertThrows(() => offerValue(o({ id: "a", price: -1 })), RangeError);
});
Deno.test("الميزانية في خطر: مفيش ترشيح", () => {
  assertEquals(rankOffers([o({ id: "a" })], true)[0].recommend, false);
  assertEquals(rankOffers([o({ id: "a" })], false)[0].recommend, true);
});
Deno.test("العمولة مش في الترتيب، ويتقال لو مش الأرخص", () => {
  const r = rankOffers([o({ id: "c", commission: true, price: 9 }), o({ id: "n", commission: false, price: 7 })], false);
  assertEquals(r.map((x) => x.id), ["n", "c"]);
  assertEquals(r[1].commissionNotCheapest, true);
  assertEquals(r[0].commissionNotCheapest, false);
});
