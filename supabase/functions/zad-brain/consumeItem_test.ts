import { assertEquals } from "jsr:@std/assert@1";
import { matchConsumeRow, openedState, piecesPerPack, quantityAfter, usedInRowUnits } from "./consumeItem.ts";
import { intentToolHints } from "./specialists.ts";
import { validateConsumeItem, freshContext } from "./validators.ts";

const row = (id: string, item_name: string, quantity: number) => ({ id, item_name, quantity, unit: "قطعة", created_at: `2026-11-0${id.length}` });

Deno.test("matchConsumeRow: the same name first, then every word the customer said, with مية = مياه", () => {
  const rows = [row("a", "مياه", 10), row("bb", "زجاجة مياه بسعة 1.5 لتر 6 قطع", 1), row("ccc", "لبن", 2)];
  assertEquals((matchConsumeRow(rows, "المياه") as any).row.id, "a");
  // Two water items: the plain one is the same name.
  assertEquals((matchConsumeRow(rows, "مية") as any).row.id, "a");
  assertEquals((matchConsumeRow([rows[1], rows[2]], "مية") as any).row.id, "bb");
  assertEquals(matchConsumeRow(rows, "زيتون"), null);
});

Deno.test("matchConsumeRow: two different items is a question, unless only one has any left", () => {
  const rows = [row("a", "جبنة رومي", 1), row("bb", "جبنة بيضا", 1)];
  assertEquals((matchConsumeRow(rows, "جبنة") as any).ambiguous.sort(), ["جبنة بيضا", "جبنة رومي"]);
  rows[1].quantity = 0;
  assertEquals((matchConsumeRow(rows, "جبنة") as any).row.id, "a");
});

Deno.test("usedInRowUnits: bottles of a 6-pack are sixths, a carton is a carton, a plain item counts as is", () => {
  const pack = "زجاجة مياه بسعة 1.5 لتر من ايلانو 6 قطع ليتر";
  assertEquals(piecesPerPack(pack), 6);
  assertEquals(usedInRowUnits(3, null, pack), 0.5);
  assertEquals(usedInRowUnits(1, "كرتونة", pack), 1);
  assertEquals(usedInRowUnits(3, null, "مياه"), 3);
  assertEquals(piecesPerPack("شاي 225 جرام"), 1);
});

Deno.test("quantityAfter never goes below zero", () => {
  assertEquals(quantityAfter(2, 0.5), 1.5);
  assertEquals(quantityAfter(1, 3), 0);
  assertEquals(quantityAfter(null, 1), 0);
});

Deno.test("«شربنا ٣ مية» and «طبخنا مكرونة» bring consume_item; «خلصنا الشغل» does not", () => {
  assertEquals(intentToolHints("شربنا ٣ مية").includes("consume_item"), true);
  assertEquals(intentToolHints("طبخنا مكرونة بالصلصة النهارده").includes("consume_item"), true);
  assertEquals(intentToolHints("أكلنا الجبنة كلها").includes("consume_item"), true);
  assertEquals(intentToolHints("خلصنا الشغل بدري").includes("consume_item"), false);
});

Deno.test("validateConsumeItem: a positive amount, at most 8 items a turn", () => {
  const ctx = freshContext("u");
  assertEquals(validateConsumeItem({ item_name: "مية", amount: 3 }, {}, ctx), { ok: true });
  assertEquals((validateConsumeItem({ item_name: "مية", amount: 0 }, {}, ctx) as any).ok, false);
  assertEquals((validateConsumeItem({ item_name: "", amount: 1 }, {}, ctx) as any).ok, false);
  ctx.counts["consume_item"] = 8;
  assertEquals((validateConsumeItem({ item_name: "مية", amount: 1 }, {}, ctx) as any).ok, false);
});

Deno.test("openedState: days since opening and what is left of its open life", () => {
  const now = Date.parse("2026-11-14T12:00:00Z");
  assertEquals(openedState("2026-11-10T12:00:00Z", 4, now), { daysAgo: 4, left: 0 });
  assertEquals(openedState("2026-11-13T12:00:00Z", 7, now), { daysAgo: 1, left: 6 });
  assertEquals(openedState("2026-11-01T12:00:00Z", null, now), { daysAgo: 13, left: null });
  assertEquals(openedState(null, 4, now), null);
});

Deno.test("validateConsumeItem: opening without using is amount 0 with opened", () => {
  assertEquals(validateConsumeItem({ item_name: "لبن", amount: 0, opened: true }, {}, freshContext("u")), { ok: true });
  assertEquals((validateConsumeItem({ item_name: "لبن", amount: 0 }, {}, freshContext("u")) as any).ok, false);
});
