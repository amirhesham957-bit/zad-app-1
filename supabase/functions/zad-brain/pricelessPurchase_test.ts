// «اشتريت ٣ علب لبن» من غير سعر: الأصناف للمخزن والمصروف لأ (pricelessPurchase.ts). المدخل حرفياً من فحص ١٤/١١.
import { assertEquals } from "jsr:@std/assert@1";
import { pantryLinesWithoutPrice, pricelessResult } from "./pricelessPurchase.ts";

Deno.test("priceless: the live call from 14/11 goes to the pantry", () => {
  const input = { lines: [{ unit: "علبة", to: "pantry", name: "لبن لتر", quantity: 3 }], amount: 0, title: "لبن لتر", txn_kind: "expense" };
  assertEquals(pantryLinesWithoutPrice(input), [{ item_name: "لبن لتر", quantity: 3, unit: "علبة" }]);
});

Deno.test("priceless: missing amount and missing quantity", () => {
  assertEquals(pantryLinesWithoutPrice({ lines: [{ name: "عيش" }] }), [{ item_name: "عيش", quantity: 1 }]);
});

Deno.test("priceless: a real amount, income, medicine only or no lines stay with the normal guard", () => {
  assertEquals(pantryLinesWithoutPrice({ amount: 90, txn_kind: "expense", lines: [{ name: "لبن", quantity: 3 }] }), null);
  assertEquals(pantryLinesWithoutPrice({ amount: 0, txn_kind: "income", lines: [{ name: "لبن" }] }), null);
  assertEquals(pantryLinesWithoutPrice({ amount: 0, txn_kind: "expense", lines: [{ name: "بنادول", to: "pharmacy" }] }), null);
  assertEquals(pantryLinesWithoutPrice({ amount: 0, txn_kind: "expense", title: "قهوة" }), null);
  assertEquals(pantryLinesWithoutPrice(null), null);
});

Deno.test("priceless: medicine lines are skipped, pantry lines kept", () => {
  assertEquals(
    pantryLinesWithoutPrice({ amount: 0, lines: [{ name: "بنادول", to: "pharmacy" }, { name: "زيت", quantity: 2, unit: "زجاجة" }] }),
    [{ item_name: "زيت", quantity: 2, unit: "زجاجة" }],
  );
});

Deno.test("priceless: the result says no expense was recorded", () => {
  const r = pricelessResult(["ضفت لبن"], []);
  assertEquals(r.includes("expense_recorded=false"), true);
  assertEquals(r.includes("added: ضفت لبن"), true);
});
