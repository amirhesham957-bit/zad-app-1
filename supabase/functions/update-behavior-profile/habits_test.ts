import { assert, assertEquals } from "jsr:@std/assert@1";
import { favoriteStores, itemCycles, localDate, shoppingRhythm } from "./habits.ts";

const NOW = Date.parse("2026-11-06T12:00:00Z");
const ago = (d: number, hourUtc = 15) => {
  const t = new Date(NOW - d * 86_400_000);
  t.setUTCHours(hourUtc, 0, 0, 0);
  return t.toISOString();
};
const tx = (merchant: string | null, amount: number, at: string, category = "البقالة") =>
  ({ merchant_name: merchant, amount, created_at: at, category, is_expense: true });

Deno.test("stores: by distinct days, then money; package names are not stores", () => {
  const s = favoriteStores([
    tx("كازيون", 50, ago(1)), tx("كازيون", 30, ago(1, 18)), tx("كازيون", 70, ago(8)),
    tx("كارفور", 900, ago(3)), tx("com.google.android.apps.messaging", 100, ago(2)),
  ], "Africa/Cairo");
  assertEquals(s.map((x) => [x.store, x.visits]), [["كازيون", 2], ["كارفور", 1]]);
  assertEquals(s[1].share, Math.round(900 / 1050 * 100));
});

Deno.test("local time, not UTC: 1 AM in Riyadh is the next day", () => {
  assertEquals(localDate(Date.parse("2026-11-05T22:30:00Z"), "Asia/Riyadh"), "2026-11-06");
  assertEquals(localDate(Date.parse("2026-11-05T22:30:00Z"), "UTC"), "2026-11-05");
});

Deno.test("rhythm: weekday and part of day only once there are 4 shopping days", () => {
  const few = shoppingRhythm([tx("كازيون", 50, ago(1))], "Africa/Cairo");
  assertEquals(few.top_weekday, null);
  // كل ٧ أيام، الساعة ٥ العصر بتوقيت القاهرة (١٥ UTC = ١٧ القاهرة).
  const weekly = shoppingRhythm([0, 7, 14, 21].map((d) => tx("كازيون", 50, ago(d))), "Africa/Cairo");
  assertEquals(weekly.typical_gap_days, 7);
  assertEquals(weekly.top_part, "evening");
  assertEquals(weekly.shopping_days, 4);
  // صرف مش أكل مش مشوار شرا.
  assertEquals(shoppingRhythm([tx("فودافون", 100, ago(1), "فواتير")], "Africa/Cairo").shopping_days, 0);
});

Deno.test("item cycles: nearest first, learned from the home's own purchases, bags left out", () => {
  const days = new Map([["زيت", ["2026-10-01", "2026-10-11", "2026-10-21"]]]);
  const c = itemCycles([
    { item_name: "زيت", quantity: 1, created_at: "2026-10-21T10:00:00Z" },
    { item_name: "سكر", quantity: 1, created_at: ago(3, 12) },
    { item_name: "شنطة كاشير", quantity: 4, created_at: ago(1) },
  ], days, NOW);
  assertEquals(c.map((x) => x.item), ["زيت", "سكر"]);
  assertEquals(c[0].cycle_days, 10);
  assert(c[0].learned);
  assert(c[0].due);
  assertEquals(c[1].learned, false);
  assertEquals(c[1].due_in_days, 30 - 3);
});
