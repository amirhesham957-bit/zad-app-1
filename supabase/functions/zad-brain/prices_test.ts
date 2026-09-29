import { assertAlmostEquals, assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { crossRate, describeRate, rankDeals, summarizePriceTrend } from "./prices.ts";

const fx = [
  { code: "USD", usd_rate: 1, updated_at: "2026-09-27T04:40:00Z" },
  { code: "EGP", usd_rate: "0.0205", updated_at: "2026-09-27T04:40:00Z" },
  { code: "SAR", usd_rate: 0.2667, updated_at: "2026-09-26T04:40:00Z" },
];

Deno.test("crossRate: through USD, oldest stamp reported", () => {
  const r = crossRate(fx, "sar", "EGP")!;
  assertAlmostEquals(r.rate, 0.2667 / 0.0205, 1e-9);
  assertEquals(r.updatedAt, "2026-09-26T04:40:00Z");
  assertEquals(crossRate(fx, "USD", "USD")!.rate, 1);
});

Deno.test("crossRate: a missing or non-positive currency is null, never a guess", () => {
  assertEquals(crossRate(fx, "USD", "TRY"), null);
  assertEquals(crossRate([{ code: "USD", usd_rate: 1 }, { code: "XXX", usd_rate: 0 }], "USD", "XXX"), null);
  assertEquals(crossRate(null, "USD", "EGP"), null);
});

Deno.test("describeRate: approximate, dated, and honest when missing", () => {
  const out = describeRate("usd", "egp", crossRate(fx, "USD", "EGP"));
  assertStringIncludes(out, "1 USD ≈ 48.78 EGP");
  assertStringIncludes(out, "2026-09-27");
  assertStringIncludes(describeRate("USD", "TRY", null), "ماتخمّنش");
});

Deno.test("summarizePriceTrend: newest first, labelled in the account's currency", () => {
  const out = summarizePriceTrend([{ price: 55 }, { price: 52 }, { price: 50 }], "لبن", 30, "EGP");
  assertStringIncludes(out, "3 بلاغ");
  assertStringIncludes(out, "آخر سعر: 55.00 EGP");
  assertStringIncludes(out, "+10.0% (صاعد)");
  assertEquals(out.includes("جنيه"), false);
});

Deno.test("summarizePriceTrend: none, one, and junk prices", () => {
  assertStringIncludes(summarizePriceTrend([], "لبن", 30, "EGP"), "screen=prices");
  assertStringIncludes(summarizePriceTrend([{ price: 40 }], "لبن", 30, "EGP"), "مفيش بيانات كفاية لاتجاه");
  // A zero price would have been a division by zero in the old code.
  assertStringIncludes(summarizePriceTrend([{ price: 40 }, { price: 0 }], "لبن", 30, "EGP"), "بلاغ واحد بس");
});

Deno.test("rankDeals: cheapest under the category mean, store and place named", () => {
  const out = rankDeals([
    { item_name: "لبن جهينة", price: 40, store_name: "كارفور", location: "المعادي" },
    { item_name: "لبن جهينة", price: 60, store_name: "سبينيس", location: null },
    { item_name: "لبن المراعي", price: 50, store_name: null, location: null },
  ], "milk", 10, "EGP");
  assertStringIncludes(out, "• كارفور، المعادي: لبن جهينة = 40.00 EGP (أقل من المتوسط بـ20%)");
  assertEquals(out.includes("سبينيس"), false);
});

Deno.test("rankDeals: too few reports or none cheap enough is said plainly", () => {
  assertStringIncludes(rankDeals([{ price: 10 }], "milk", 10, "EGP"), "ماتخترعش");
  assertStringIncludes(rankDeals([{ price: 10 }, { price: 10 }], "milk", 10, "EGP"), "مفيش بلاغ");
});
