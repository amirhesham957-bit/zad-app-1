import { assertEquals } from "jsr:@std/assert@1";
import { computeNeeds, priorDaysMap } from "./amazonNeeds.ts";

Deno.test("computeNeeds: a home with no learned rate still sees bread running out, on the household prior", () => {
  const inv = [
    { item_name: "عيش", quantity: 10, low_stock_threshold: 2 },
    { item_name: "شاي", quantity: 5, low_stock_threshold: 2 },
  ];
  const prior = priorDaysMap([
    { item_name: "عيش", days_left: "1.5", held: false },
    { item_name: "شاي", days_left: 18.8, held: false },
  ]);
  const needs = computeNeeds(inv, [], [], 10, prior);
  assertEquals(needs.map((n) => [n.name, n.score]), [["عيش", 4]]);
  assertEquals(needs[0].reason.includes("أفراد البيت"), true);
  // Without the prior: nothing — the bread is above its threshold and has no rate.
  assertEquals(computeNeeds(inv, [], [], 10).length, 0);
  // A learned rate beats the prior.
  assertEquals(computeNeeds(inv, [{ item_name: "عيش", avg_daily_qty: 1, rate_known: true }], [], 10, prior).map((n) => n.score), [1]);
});

Deno.test("priorDaysMap: «لسه» holds an item out, and junk rows are dropped", () => {
  const m = priorDaysMap([{ item_name: "عيش", days_left: 0, held: true }, { item_name: "لبن", days_left: null }, { item_name: "رز", days_left: 2 }, null, "x"]);
  assertEquals([...m.entries()], [["رز", 2]]);
});
