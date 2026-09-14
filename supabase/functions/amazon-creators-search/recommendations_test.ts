import { assertEquals } from "jsr:@std/assert@1";
import { computeNeeds, marketFor, matchCatalog, searchUrl } from "./recommendations.ts";

Deno.test("needs rank run-outs by consumption above low stock and the shopping list", () => {
  const needs = computeNeeds(
    [
      { item_name: "بيض", quantity: 0, low_stock_threshold: 2 },
      { item_name: "لبن", quantity: 2, low_stock_threshold: 1 },
      { item_name: "رز", quantity: 1, low_stock_threshold: 2 },
      { item_name: "سكر", quantity: 50, low_stock_threshold: 2 },
    ],
    [{ item_name: "لبن", avg_daily_qty: 1, rate_known: true }, { item_name: "سكر", avg_daily_qty: 0.1, rate_known: true }],
    [{ item_name: "فراخ", is_purchased: false }, { item_name: "بيض", is_purchased: false }],
  );
  assertEquals(needs.map((n) => n.name), ["بيض", "لبن", "رز", "فراخ"]);
  assertEquals(needs[1].reason.includes("استهلاكك"), true);
});

Deno.test("tag and domain come from project secrets, per country first", () => {
  const env: Record<string, string> = { AMAZON_ASSOCIATE_TAG: "mine-21", AMAZON_ASSOCIATE_TAG_EG: "egtag-21", AMAZON_DOMAIN_EG: "www.amazon.eg" };
  assertEquals(marketFor("EG", (n) => env[n]), { domain: "www.amazon.eg", tag: "egtag-21" });
  assertEquals(marketFor("SA", (n) => env[n]), { domain: "www.amazon.sa", tag: "mine-21" });
  assertEquals(marketFor(null, () => undefined), { domain: "www.amazon.sa", tag: null });
  assertEquals(marketFor("EG", (n) => ({ AMAZON_DOMAIN_EG: "evil.com" } as Record<string, string>)[n]).domain, "www.amazon.sa");
  assertEquals(searchUrl({ domain: "www.amazon.sa", tag: "mine-21" }, "زيت زيتون"), "https://www.amazon.sa/s?k=%D8%B2%D9%8A%D8%AA%20%D8%B2%D9%8A%D8%AA%D9%88%D9%86&tag=mine-21");
});

Deno.test("catalog match needs a real name/keyword overlap", () => {
  const cat = [{ id: "1", product_name_ar: "زيت زيتون بكر", product_name_search_keywords: ["زيت"], asin: null, asin_verified: false, image_url: "x", average_price_sar: 28, is_active: true }];
  assertEquals(matchCatalog({ name: "زيت", reason: "", score: 3, days_left: null }, cat)?.id, "1");
  assertEquals(matchCatalog({ name: "بيض", reason: "", score: 3, days_left: null }, cat), null);
});
