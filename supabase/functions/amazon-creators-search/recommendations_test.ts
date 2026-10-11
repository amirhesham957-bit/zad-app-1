import { assertEquals } from "jsr:@std/assert@1";
import { amazonImageOrNull, computeNeeds, marketFor, matchCatalog, productUrl, searchUrl } from "./recommendations.ts";

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

Deno.test("Egypt shops amazon.eg with its own tag; every other country amazon.sa", () => {
  const none = () => undefined;
  assertEquals(marketFor("EG", none), { domain: "www.amazon.eg", tag: "zad04-21" });
  assertEquals(marketFor("eg", none).domain, "www.amazon.eg");
  for (const cc of ["SA", "AE", "KW", "QA", "TR", null]) {
    assertEquals(marketFor(cc, none), { domain: "www.amazon.sa", tag: "zad0b-21" });
  }
  assertEquals(productUrl(marketFor("EG", none), "B0ABCDEF12"), "https://www.amazon.eg/dp/B0ABCDEF12?tag=zad04-21");
  assertEquals(searchUrl({ domain: "www.amazon.sa", tag: "mine-21" }, "زيت زيتون"), "https://www.amazon.sa/s?k=%D8%B2%D9%8A%D8%AA%20%D8%B2%D9%8A%D8%AA%D9%88%D9%86&tag=mine-21");
});

Deno.test("secrets override a store's tag, and a new store needs both its domain and its tag", () => {
  const env: Record<string, string> = {
    AMAZON_ASSOCIATE_TAG: "mine-21", AMAZON_ASSOCIATE_TAG_EG: "egtag-21",
    AMAZON_DOMAIN_AE: "www.amazon.ae", AMAZON_ASSOCIATE_TAG_AE: "aetag-21", AMAZON_DOMAIN_KW: "www.amazon.ae",
  };
  const get = (n: string) => env[n];
  assertEquals(marketFor("EG", get), { domain: "www.amazon.eg", tag: "egtag-21" });
  assertEquals(marketFor("SA", get), { domain: "www.amazon.sa", tag: "mine-21" });
  assertEquals(marketFor("AE", get), { domain: "www.amazon.ae", tag: "aetag-21" });
  // A domain without its own tag would carry the Saudi tag to a store where it earns nothing.
  assertEquals(marketFor("KW", get), { domain: "www.amazon.sa", tag: "mine-21" });
  assertEquals(marketFor("KW", (n) => ({ AMAZON_DOMAIN_KW: "evil.com", AMAZON_ASSOCIATE_TAG_KW: "x-21" } as Record<string, string>)[n]).domain, "www.amazon.sa");
  // A Saudi-store override never moves Egypt off amazon.eg.
  assertEquals(marketFor("EG", (n) => ({ AMAZON_ASSOCIATE_TAG: "mine-21" } as Record<string, string>)[n]), { domain: "www.amazon.eg", tag: "zad04-21" });
});

Deno.test("catalog match needs a real name/keyword overlap", () => {
  const cat = [{ id: "1", product_name_ar: "زيت زيتون بكر", product_name_search_keywords: ["زيت"], asin: null, asin_verified: false, image_url: "x", average_price_sar: 28, is_active: true }];
  assertEquals(matchCatalog({ name: "زيت", reason: "", score: 3, days_left: null }, cat)?.id, "1");
  assertEquals(matchCatalog({ name: "بيض", reason: "", score: 3, days_left: null }, cat), null);
});

Deno.test("amazonImageOrNull: only Amazon's own product photos", () => {
  assertEquals(amazonImageOrNull("https://m.media-amazon.com/images/I/71abc.jpg"), "https://m.media-amazon.com/images/I/71abc.jpg");
  assertEquals(amazonImageOrNull("https://images-na.ssl-images-amazon.com/images/I/x.jpg"), "https://images-na.ssl-images-amazon.com/images/I/x.jpg");
  assertEquals(amazonImageOrNull("https://images.pexels.com/photos/1.jpeg"), null);
  assertEquals(amazonImageOrNull("http://m.media-amazon.com/x.jpg"), null);
  assertEquals(amazonImageOrNull("https://evil.com/m.media-amazon.com.jpg"), null);
  assertEquals(amazonImageOrNull(null), null);
});
