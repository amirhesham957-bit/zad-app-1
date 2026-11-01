import { assertEquals } from "jsr:@std/assert@1";
import {
  apiUrl, categoryByOffer, countriesByOffer, dataOf, logoByOffer, markTrending, offerRows, offersOf, storeOf,
  trackingLinkOf,
} from "./hasoffers.ts";
import { couponRows } from "./dcm.ts";

const SYNCED = "2026-11-01T09:00:00.000Z";
// Shapes copied from real answers on 2026-11-01 (trimmed).
const findAll = {
  page: 1, count: 3, data: {
    "685": { Offer: { id: "685", name: "Amazon | UAE | Links", payout_type: "cpa_percentage", percent_payout: "6.30", default_payout: "0.00000", currency: "AED", status: "active", approval_status: "approved", featured: "2026-01-30 09:22:59" } },
    "194": { Offer: { id: "194", name: "800 Flower | UAE | Links", payout_type: "cpa_percentage", percent_payout: "10.50", default_payout: "8.00000", currency: "AED", status: "active", approval_status: "approved", featured: "0000-00-00 00:00:00" } },
    "900": { Offer: { id: "900", name: "Shopify | Global | Links", payout_type: "cpa_flat", percent_payout: "0.00", default_payout: "17.50000", currency: null, status: "active", approval_status: "approved", featured: null } },
    "901": { Offer: { id: "901", name: "Farfetch | Links | Content Sites Only", payout_type: "cpa_percentage", percent_payout: "2.10", status: "active", approval_status: null } },
  },
};

Deno.test("findAll keeps active approved offers, store before the first «|», flat payouts apart", () => {
  const offers = offersOf(findAll);
  assertEquals(offers.map((o) => [o.id, o.store, o.payoutPercent, o.payoutFlat]), [
    ["194", "800 Flower", 10.5, null], ["685", "Amazon", 6.3, null], ["900", "Shopify", null, 17.5],
  ]);
  assertEquals(offers[0].featuredAt, null);
  assertEquals(storeOf("H&M | AE BH JR KW QA SA | Link"), "H&M");
});

Deno.test("a refused answer gives its message, never the request echo", () => {
  assertEquals(dataOf({ request: { api_key: "SECRET" }, response: { status: -1, errors: [{ publicMessage: "Invalid API key" }] } }),
    { ok: false, error: "Invalid API key" });
  assertEquals(dataOf({ response: { status: 1, data: [1] } }), { ok: true, data: [1] });
});

Deno.test("countries, categories and logos by offer; an offer with no countries is absent", () => {
  const countries = countriesByOffer([{ offer_id: "685", countries: { AE: { code: "AE" }, SA: { code: "SA" } } }]);
  assertEquals([...countries], [["685", ["AE", "SA"]]]);
  assertEquals([...categoryByOffer([{ offer_id: "685", categories: { "38": { name: "Departmental Store" } } }])],
    [["685", "Departmental Store"]]);
  const logos = logoByOffer([{ offer_id: "685", Thumbnail: { "1": { url: "https://media.go2speed.org/brand/files/dcm/685/amazon 25x250.jpeg", thumbnail: "https://media.go2speed.org/brand/files/dcm/685/thumbnails_100/amazon 25x250.jpeg", width: "250", height: "250" } } }]);
  assertEquals(logos.get("685"), "https://media.go2speed.org/brand/files/dcm/685/thumbnails_100/amazon%2025x250.jpeg");
});

Deno.test("no tracking link until the offer's terms are accepted", () => {
  assertEquals(trackingLinkOf({ click_url: "", message: "Must accept offer terms and conditions for offer id #685 before tracking link can be generated." }),
    { reason: "needs_terms" });
  assertEquals(trackingLinkOf({ click_url: "https://dcm.go2cloud.org/aff_c?offer_id=685&aff_id=174133" }),
    { url: "https://dcm.go2cloud.org/aff_c?offer_id=685&aff_id=174133" });
});

Deno.test("one row per target country, GLOBAL when none; only linked offers can trend", () => {
  const offers = offersOf(findAll);
  const rows = offerRows(offers, new Map([["685", ["AE", "SA"]], ["194", ["AE"]]]), new Map(), new Map(),
    new Map([["685", "https://t/685"], ["900", "https://t/900"]]), SYNCED);
  assertEquals(rows.map((r) => [r.external_id, r.country_code, r.is_trending]), [
    ["194", "AE", false], ["685", "AE", true], ["685", "SA", true], ["900", "GLOBAL", false],
  ]);
});

Deno.test("trending = top commissions per country, ties to the most recently featured", () => {
  const offers = [
    { id: "a", store: "A", title: "A", payoutPercent: 5, payoutFlat: null, payoutCurrency: null, featuredAt: "2025-01-01" },
    { id: "b", store: "B", title: "B", payoutPercent: 5, payoutFlat: null, payoutCurrency: null, featuredAt: "2026-01-01" },
    { id: "c", store: "C", title: "C", payoutPercent: 9, payoutFlat: null, payoutCurrency: null, featuredAt: null },
  ];
  const rows = offerRows(offers, new Map(), new Map(), new Map(),
    new Map([["a", "https://t/a"], ["b", "https://t/b"], ["c", "https://t/c"]]), SYNCED);
  const top2 = markTrending(rows.map((r) => ({ ...r, is_trending: false })), offers, 2);
  assertEquals(top2.filter((r) => r.is_trending).map((r) => r.external_id), ["b", "c"]);
});

Deno.test("a Codes Hub coupon keeps its code, one row per country, even with no price", () => {
  const rows = couponRows({
    IdPK: "SAVE10-1365", brand: "Noon", coupon: "SAVE10", coupon_desc: "Up to 10% Cashback", countries: "UAE, KSA",
    user_terms: "Valid until 30-12-2026", web_link: "https://dcm.go2cloud.org/aff_c?offer_id=1365&aff_id=1",
  }, Date.parse("2026-11-01T00:00:00Z"), SYNCED);
  assertEquals(rows?.map((r) => [r.country_code, r.code, r.valid_until]), [
    ["AE", "SAVE10", "2026-12-30T23:59:59.000Z"], ["SA", "SAVE10", "2026-12-30T23:59:59.000Z"],
  ]);
  assertEquals(couponRows({ IdPK: "x", brand: "Noon", web_link: "http://insecure" }, 0, SYNCED), null);
});

Deno.test("the API key is a query parameter, ids[] repeated", () => {
  const u = new URL(apiUrl("dcm", "K", "Affiliate_Offer", "getCategories", { "ids[]": ["1", "2"] }));
  assertEquals(u.host, "dcm.api.hasoffers.com");
  assertEquals(u.searchParams.getAll("ids[]"), ["1", "2"]);
});
