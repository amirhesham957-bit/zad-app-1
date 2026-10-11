import { assertEquals } from "jsr:@std/assert@1";
import { normalizeItemName, pickPantryMatch, samePantryItem } from "./pantryMatch.ts";

Deno.test("names normalise the way the app's normalizeItemName does", () => {
  assertEquals(normalizeItemName("  الجبنة   الرومي "), "جبنه رومي");
  assertEquals(normalizeItemName("إندومي"), normalizeItemName("اندومي"));
  assertEquals(normalizeItemName("مستشفى"), "مستشفي");
  assertEquals(normalizeItemName("Cream Cheese"), "cream cheese");
});

Deno.test("the same item, spelled or ordered differently", () => {
  assertEquals(samePantryItem("بلح", "البلح"), true);
  assertEquals(samePantryItem("برانش توست", "توست برانش"), true);
  assertEquals(samePantryItem("جبنة رومي", "الجبنه الرومي"), true);
});

Deno.test("a different item is not folded in", () => {
  assertEquals(samePantryItem("لبن", "لبن زبادي"), false);
  assertEquals(samePantryItem("توست", "برانش توست"), false);
  assertEquals(samePantryItem("", "بلح"), false);
});

const rows = [
  { id: "old", item_name: "بلح", quantity: 0, unit: "كيلو", created_at: "2026-09-20T00:00:00Z" },
  { id: "new", item_name: "البلح", quantity: 1, unit: "كيلو", created_at: "2026-10-01T00:00:00Z" },
  { id: "bag", item_name: "سكر", quantity: 5, unit: "كيس", created_at: "2026-10-01T00:00:00Z" },
  { id: "toast", item_name: "توست برانش", quantity: 0, unit: null, created_at: "2026-09-01T00:00:00Z" },
];

Deno.test("buying بلح again tops up the row already there", () => {
  // Exact name after normalising beats a reordered one; the newest exact row wins.
  assertEquals(pickPantryMatch(rows, "بلح", "كيلو")?.id, "new");
  assertEquals(pickPantryMatch(rows, "بلح")?.id, "new");
  assertEquals(pickPantryMatch(rows, "برانش توست", "حبة")?.id, "toast", "a row with no unit takes any");
});

Deno.test("another unit or another item is a new row", () => {
  assertEquals(pickPantryMatch(rows, "سكر", "كيلو"), null);
  assertEquals(pickPantryMatch(rows, "لبن"), null);
  assertEquals(pickPantryMatch([], "بلح"), null);
});
