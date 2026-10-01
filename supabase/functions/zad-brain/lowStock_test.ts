import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { lowStockToAdd, productFamilyOf, normalizeItemName } from "./lowStock.ts";

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

Deno.test("٨ إزازات مية من ٥ ماركات مخزون واحد — مش ناقص", () => {
  const pantry = [
    { item_name: "ماء إيلان", quantity: 1 }, { item_name: "ماء بونا", quantity: 1 },
    { item_name: "مياه إيلانو", quantity: 0 }, { item_name: "مياه داساني", quantity: 1 },
    { item_name: "مياه نستله", quantity: 5 },
  ];
  assertEquals(lowStockToAdd(pantry, []), []);
});

Deno.test("السلعة الأساسية لما مجموعها يوصل الحد بتنزل مرة باسمها", () => {
  const pantry = [{ item_name: "ماء إيلان", quantity: 0 }, { item_name: "مياه نستله", quantity: 1 }];
  assertEquals(lowStockToAdd(pantry, []), ["مياه"]);
  assertEquals(lowStockToAdd(pantry, ["مياه"]), []);
});

Deno.test("زيت زيتون مش زيت عباد — مابيتجمعوش", () => {
  assertEquals(productFamilyOf("زيت زيتون"), null);
  assertEquals(productFamilyOf("الأرز البسمتي"), "رز");
});

Deno.test("التعبئة والـ«ماية» مابتخبيش السلعة — نفس جدول التطبيق (2026-10-01)", () => {
  assertEquals(productFamilyOf("عبوة مياه"), "مياه");
  assertEquals(productFamilyOf("كرتونة ماية"), "مياه");
  assertEquals(productFamilyOf("كيس سكر"), "سكر");
  assertEquals(productFamilyOf("علبة حفظ طعام"), null);
  assertEquals(productFamilyOf("علبة"), null);
});

Deno.test("productFamilyOf: brand-first water joins the water family, other staples do not", () => {
  // The owner's pantry on 2026-10-01: «صافي مياه معدنية 1.5 لتر» beside nine other water rows.
  assertEquals(productFamilyOf("صافي مياه معدنية 1.5 لتر"), "مياه");
  assertEquals(productFamilyOf("نستله مياه"), "مياه");
  assertEquals(productFamilyOf("ماء صافى"), "مياه");
  assertEquals(productFamilyOf("بسكويت شاي"), null);
  assertEquals(productFamilyOf("عصير سكر"), null);
});
