import { assert, assertEquals } from "jsr:@std/assert@1";
import { describeWhereToBuy, whereToBuy } from "./whereToBuy.ts";

const NOW = Date.parse("2026-11-06T12:00:00Z");
const ago = (d: number) => new Date(NOW - d * 86_400_000).toISOString();
const r = (store: string, price: number, days: number, user: string, item = "زيت عافية 1.5 لتر", location = "القاهرة") =>
  ({ item_name: item, store_name: store, price, timestamp: ago(days), user_id: user, location });

Deno.test("three homes: prices are said, cheapest store first", () => {
  const w = whereToBuy("زيت عافية", [r("كازيون", 120, 2, "a"), r("بيم", 110, 5, "b"), r("كارفور", 135, 1, "c")], [], NOW, new Map(), "القاهرة");
  assertEquals(w.typical, 120);
  assertEquals(w.stores.map((s) => s.store), ["بيم", "كازيون", "كارفور"]);
  assertEquals(w.stores[0].price, 110);
});

Deno.test("under three homes: where it was seen, never the price (crowd floor)", () => {
  // نفس البيت (عيلة واحدة) بلّغ ٣ مرات = بيت واحد.
  const fam = new Map([["a", "f1"], ["b", "f1"], ["c", "f1"]]);
  const w = whereToBuy("زيت عافية", [r("كازيون", 120, 2, "a"), r("بيم", 110, 5, "b"), r("كارفور", 135, 1, "c")], [], NOW, fam);
  assertEquals(w.typical, null);
  assert(w.stores.every((s) => s.price === null));
  assertEquals(w.stores[0].store, "كارفور"); // الأحدث الأول
  assert(!describeWhereToBuy(w, "EGP").includes("135"));
});

Deno.test("another city, another item and old reports are left out", () => {
  const w = whereToBuy("زيت عافية", [
    r("بيم", 100, 2, "a", "زيت عافية", "الإسكندرية"), r("بيم", 100, 40, "b"), r("بيم", 100, 1, "c", "سكر"),
  ], [], NOW, new Map(), "القاهرة");
  assertEquals(w.stores, []);
});

Deno.test("a running deal on the item is listed with its old price", () => {
  const w = whereToBuy("زيت", [], [
    { store: "كارفور", item_name: "زيت عافية 1.5 لتر", price: 99, price_before: 130, valid_until: "2026-11-10T00:00:00Z" },
    { store: "كارفور", item_name: "سكر 1 كجم", price: 30 },
  ], NOW);
  assertEquals(w.deals.length, 1);
  assert(describeWhereToBuy(w, "EGP").includes("بـ99 EGP بدل 130 لحد 2026-11-10"));
});

Deno.test("nothing found says so and never invents a store", () => {
  const text = describeWhereToBuy(whereToBuy("زعفران", [], [], NOW), "EGP");
  assert(text.includes("ماتخترعش"));
});
