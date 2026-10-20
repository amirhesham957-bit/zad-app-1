import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { qtyFromFraction } from "./readingFraction.ts";
import { validateUpdateInventoryQty } from "./validators.ts";

Deno.test("half of the last purchase, not half of what the row says now", () => {
  // اشترى ٥ كيلو رز، والمخزون لسه مكتوب فيه ٥ — «فاضل نصه» = ٢٫٥.
  assertEquals(qtyFromFraction(0.5, 5, 5), 2.5);
  // المخزون نزل لـ٣ بقراية قديمة، والمرجع لسه العبوة: ٥ × ٠٫٢ = ١.
  assertEquals(qtyFromFraction(0.2, 5, 3), 1);
});

Deno.test("no purchase on record: the stock row is the reference", () => {
  assertEquals(qtyFromFraction(0.5, null, 2), 1);
  assertEquals(qtyFromFraction(0.75, 0, 4), 3);
});

Deno.test("finished is zero even with nothing to measure against", () => {
  assertEquals(qtyFromFraction(0, null, null), 0);
});

Deno.test("no reference, or a fraction outside 0..1, gives no quantity", () => {
  assertEquals(qtyFromFraction(0.5, null, 0), null);
  assertEquals(qtyFromFraction(1.5, 5, 5), null);
  assertEquals(qtyFromFraction(-0.1, 5, 5), null);
  assertEquals(qtyFromFraction(Number.NaN, 5, 5), null);
});

Deno.test("thirds round to grams, not a long tail", () => {
  assertEquals(qtyFromFraction(1 / 3, 1, 1), 0.333);
});

const snap = { stock: [{ name: "زيت", qty: 1 }] };

Deno.test("the validator takes a fraction in place of a number", () => {
  assertEquals(
    validateUpdateInventoryQty({ item_name: "زيت", fraction_left: 0.5, reason: "العميل قال فاضل نصه" }, snap as any, {} as any),
    { ok: true },
  );
});

Deno.test("the validator refuses a fraction outside 0..1 and an unknown item", () => {
  assertEquals(
    (validateUpdateInventoryQty({ item_name: "زيت", fraction_left: 2, reason: "العميل قال فاضل نصه" }, snap as any, {} as any) as { ok: boolean }).ok,
    false,
  );
  assertEquals(
    (validateUpdateInventoryQty({ item_name: "رز", fraction_left: 0.5, reason: "العميل قال فاضل نصه" }, snap as any, {} as any) as { ok: boolean }).ok,
    false,
  );
});

Deno.test("a number and a fraction together is ambiguous and refused", () => {
  assertEquals(
    (validateUpdateInventoryQty({ item_name: "زيت", new_qty: 1, fraction_left: 0.5, reason: "العميل قال فاضل نصه" }, snap as any, {} as any) as { ok: boolean }).ok,
    false,
  );
});
