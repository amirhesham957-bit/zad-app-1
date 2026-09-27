import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { lowStockToAdd, normalizeItemName } from "./lowStock.ts";

Deno.test("an item bought from the list before comes back when it runs low", () => {
  // Only open rows are passed: the old purchased row no longer hides it.
  assertEquals(lowStockToAdd([{ item_name: "لبن", quantity: 0 }], []), ["لبن"]);
});

Deno.test("already open on the list: not added twice, spelling-insensitive", () => {
  assertEquals(lowStockToAdd([{ item_name: "زبدة طبيعية", quantity: 1 }], ["  زبده   طبيعيه "]), []);
});

Deno.test("the item's own threshold wins over the default of one", () => {
  const pantry = [
    { item_name: "بيض", quantity: 4, low_stock_threshold: 6 },
    { item_name: "رز", quantity: 2, low_stock_threshold: null },
    { item_name: "سكر", quantity: 1 },
  ];
  assertEquals(lowStockToAdd(pantry, []), ["بيض", "سكر"]);
});

Deno.test("each name once; blank names and junk quantities skipped", () => {
  const pantry = [
    { item_name: "زيت", quantity: 0 },
    { item_name: "زيت ", quantity: 1 },
    { item_name: "", quantity: 0 },
    { item_name: "ملح", quantity: "abc" },
    { item_name: "خل", quantity: -1 },
  ];
  assertEquals(lowStockToAdd(pantry, [null]), ["زيت"]);
});

Deno.test("normalizeItemName folds alef, taa marbuta, yaa and spaces", () => {
  assertEquals(normalizeItemName(" أرز  مصرى "), "ارز مصري");
});
