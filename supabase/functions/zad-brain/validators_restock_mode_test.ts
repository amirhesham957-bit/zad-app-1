// ZAD_PLAN ٣.١٠: «دي مش أساسية» من غير كمية.
import { assertEquals } from "jsr:@std/assert@1";
import { validateUpdateInventoryQty } from "./validators.ts";

const snap = { stock: [{ name: "رنجة", qty: 0 }] } as any;
const ctx = { counts: {} } as any;

Deno.test("a mode with no quantity is a valid change", async () => {
  assertEquals((await validateUpdateInventoryQty({ item_name: "رنجة", restock_mode: "occasional", reason: "العميل قال مش أساسية" }, snap, ctx)).ok, true);
  assertEquals((await validateUpdateInventoryQty({ item_name: "رنجة", restock_mode: "staple", reason: "العميل قال دي أساسية" }, snap, ctx)).ok, true);
});

Deno.test("neither a quantity nor a mode, an unknown mode, or an unknown item is refused", async () => {
  assertEquals((await validateUpdateInventoryQty({ item_name: "رنجة", reason: "مفيش حاجة اتغيرت هنا" }, snap, ctx)).ok, false);
  assertEquals((await validateUpdateInventoryQty({ item_name: "رنجة", restock_mode: "weekly", reason: "نوع مش موجود خالص" }, snap, ctx)).ok, false);
  assertEquals((await validateUpdateInventoryQty({ item_name: "فسيخ", restock_mode: "occasional", reason: "صنف مش في المخزن" }, snap, ctx)).ok, false);
});

Deno.test("a quantity is still checked as before", async () => {
  assertEquals((await validateUpdateInventoryQty({ item_name: "رنجة", new_qty: -1, reason: "كمية بالسالب غلط" }, snap, ctx)).ok, false);
  assertEquals((await validateUpdateInventoryQty({ item_name: "رنجة", new_qty: 1, reason: "اشترى واحدة جديدة" }, snap, ctx)).ok, true);
});
