import { assertEquals } from "jsr:@std/assert@1";
import { type DealRow, resolveCountry, shapeDeals } from "./deals.ts";

const row = (o: Partial<DealRow>): DealRow => ({
  source: "dcm_offer", external_id: "1", country_code: "AE", store: "S", title: "", code: null, category: null,
  click_url: "https://t/1", logo_url: null, payout_percent: null, is_trending: false, valid_until: null, ...o,
});

Deno.test("country: ?country first, then travel, then the account; junk is skipped", () => {
  assertEquals(resolveCountry("sa", { country: "EG" }), "SA");
  assertEquals(resolveCountry(null, { country: "EG", travel_country: "AE" }), "AE");
  assertEquals(resolveCountry("Saudi", { country: "eg" }), "EG");
  assertEquals(resolveCountry(null, null), null);
});

Deno.test("own country's rows plus GLOBAL; trending only flagged rows; codes first, then commission", () => {
  const rows = [
    row({ external_id: "a", store: "Amazon", payout_percent: 6.3, is_trending: true }),
    row({ external_id: "b", store: "Flowers", payout_percent: 10.5, is_trending: true }),
    row({ external_id: "c", store: "Noon", code: "SAVE10", source: "dcm_coupon" }),
    row({ external_id: "g", store: "Airalo", country_code: "GLOBAL", payout_percent: 7 }),
  ];
  const out = shapeDeals(rows, "AE");
  assertEquals(out.fallback, null);
  assertEquals(out.trending_deals.map((r) => r.external_id), ["b", "a"]);
  assertEquals(out.available_coupons.map((r) => r.external_id), ["c", "b", "g", "a"]);
});

Deno.test("no rows for the country (Egypt, measured 2026-11-01) ⇒ GLOBAL only, said so", () => {
  const rows = [row({ external_id: "g", country_code: "GLOBAL", is_trending: true, payout_percent: 7 })];
  const out = shapeDeals(rows, "EG");
  assertEquals([out.fallback, out.trending_deals.length, out.available_coupons.length], ["global", 1, 1]);
  assertEquals(shapeDeals([], null).fallback, "global");
});
