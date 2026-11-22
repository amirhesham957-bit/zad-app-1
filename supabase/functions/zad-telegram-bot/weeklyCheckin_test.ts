import { assertEquals } from "jsr:@std/assert@1";
import { lastAskedDaysAgo, weeklyGateClosed, weeklyPick } from "./weeklyCheckin.ts";

const NOW = Date.UTC(2026, 10, 20, 18);
const ago = (d: number) => new Date(NOW - d * 86_400_000).toISOString();
const cand = (item_name: string, quantity: number, essential = false) => ({ item_name, quantity, essential, why: { kind: "rate" } });

Deno.test("the gate: asked 3 days ago ⇒ closed; 8 days ago or never ⇒ open", () => {
  assertEquals(weeklyGateClosed(lastAskedDaysAgo(ago(3), NOW)), true);
  assertEquals(weeklyGateClosed(lastAskedDaysAgo(ago(8), NOW)), false);
  assertEquals(weeklyGateClosed(lastAskedDaysAgo(null, NOW)), false);
  assertEquals(lastAskedDaysAgo("garbage", NOW), null);
});

Deno.test("closed week ⇒ nobody is asked, even a pressing item", () => {
  const picked = weeklyPick([cand("عيش", 2, true)], [{ item_name: "عيش", quantity: 2, prior_daily: 5, readings: [] }], 2, NOW);
  assertEquals(picked, []);
});

Deno.test("at most three, the most valuable first, bundled; no forecast = not asked", () => {
  const cands = [cand("سكر", 1), cand("عيش", 2, true), cand("لبن", 1, true), cand("شاي", 1), cand("خيار", 2)];
  const inputs = [
    { item_name: "سكر", quantity: 1, prior_daily: 0.02, readings: [] },
    { item_name: "عيش", quantity: 2, prior_daily: 5, readings: [] },
    { item_name: "لبن", quantity: 1, prior_daily: 0.5, readings: [] },
    { item_name: "شاي", quantity: 1, prior_daily: 0.05, readings: [] },
    { item_name: "خيار", quantity: 2, prior_daily: null, readings: [] },
  ];
  const picked = weeklyPick(cands, inputs, null, NOW).map((c) => c.item_name);
  assertEquals(picked.length, 3);
  assertEquals(picked.includes("خيار"), false);
  // العيش (ضروري وبيخلص بكرة) أول واحد.
  assertEquals(picked[0], "عيش");
});

Deno.test("an item read yesterday is worth less than the same item never read", () => {
  const cands = [cand("أ", 1, true), cand("ب", 1, true)];
  const inputs = [
    { item_name: "أ", quantity: 1, prior_daily: 0.5, readings: [{ qty: 1, at: ago(1) }] },
    { item_name: "ب", quantity: 1, prior_daily: 0.5, readings: [] },
  ];
  assertEquals(weeklyPick(cands, inputs, null, NOW, 1).map((c) => c.item_name), ["ب"]);
});
