import { assertEquals } from "jsr:@std/assert@1";
import { dealPutPayload, searchedDeals } from "./storeDeals.ts";

const target = { country: "SA", store: "كيو", currency: "SAR" };

Deno.test("a searched offer becomes a country-wide search row with its link", () => {
  const row = dealPutPayload(target, {
    item_name: "زيت عافية ١.٥ لتر", price: 21.95, price_before: 27.5,
    valid_until: "2026-10-31T23:59:59.000Z", source_url: "https://example.com/q",
  });
  assertEquals(row.city, "");
  assertEquals(row.source_kind, "search");
  assertEquals(row.deal_kind, "discount");
  assertEquals(row.currency, "SAR");
  assertEquals(row.source_url, "https://example.com/q");
});

Deno.test("an offer with no price before is a plain price", () => {
  const row = dealPutPayload(target, {
    item_name: "رز", price: 40, price_before: null, valid_until: null, source_url: "https://example.com/r",
  });
  assertEquals(row.deal_kind, "price");
  assertEquals(row.valid_until, null);
});

Deno.test("only well-formed deals from store_deals are kept", () => {
  assertEquals(searchedDeals(null), []);
  assertEquals(searchedDeals({ deals: "x" }), []);
  const kept = searchedDeals({
    deals: [
      { item_name: "رز", price: 40, price_before: null, valid_until: null, source_url: "https://a.com" },
      { item_name: "سكر", price: "12", source_url: "https://a.com" },
      { price: 3, source_url: "https://a.com" },
    ],
  });
  assertEquals(kept.map((d) => d.item_name), ["رز"]);
});
