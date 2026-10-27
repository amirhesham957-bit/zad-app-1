import { assertEquals } from "jsr:@std/assert@1";
import { countriesOf, couponsOf, mapCoupon, validUntil } from "./dcm.ts";

const NOW = Date.parse("2026-10-27T12:00:00Z");
// The data points of DCM's "Get Active Coupons" (their Publisher APIs page), spelled as they list them.
const noon = {
  IdPK: "SAVE10-1365",
  brand: "Noon",
  logo: "https://media.go2speed.org/brand/files/dcm/1365/Noon_300x300%20logo.jpg",
  coupon: "SAVE10",
  coupon_desc: "Up to 10% Cashback",
  user_terms: "Valid on selected Express items\nValid on orders above AED 40\nValid until 30-12-2026",
  countries: "UAE, KSA",
  website: "https://www.noon.com",
  web_link: "https://dcm.go2cloud.org/aff_c?offer_id=1365&aff_id=1",
};

Deno.test("their own example — a store-wide cashback code — is counted, not given a price", () => {
  assertEquals(mapCoupon(noon, NOW), { ok: false, reason: "discount_not_price" });
});

Deno.test("a description with a price in one of its countries' currency becomes a partner deal", () => {
  const m = mapCoupon({ ...noon, coupon_desc: "زيت عافية ١٫٥ لتر بـ٢٥ ريال بدل ٣٢", countries: "KSA" }, NOW);
  assertEquals(m, {
    ok: true,
    payload: {
      country: "SA", city: "", store: "Noon", item_name: "زيت عافية 1.5 لتر", price: 25, price_before: 32,
      currency: "SAR", deal_kind: "discount", valid_until: "2026-12-30T23:59:59.000Z",
      source_kind: "partner", source_url: "https://dcm.go2cloud.org/aff_c?offer_id=1365&aff_id=1", confidence: 0.55,
    },
  });
});

Deno.test("a price in AED offered in UAE and KSA goes to the UAE only", () => {
  const m = mapCoupon({ ...noon, coupon_desc: "Airpods 4 at 499 AED" }, NOW);
  assertEquals(m.ok && m.payload.country, "AE");
});

Deno.test("riyal named in two riyal markets is ambiguous; a currency of none of its countries is no market", () => {
  assertEquals(mapCoupon({ ...noon, coupon_desc: "تمر سكري ٣ كيلو بـ٤٥ ريال", countries: "KSA, Qatar" }, NOW), { ok: false, reason: "ambiguous_market" });
  assertEquals(mapCoupon({ ...noon, coupon_desc: "تمر سكري ٣ كيلو بـ٤٥ جنيه", countries: "KSA" }, NOW), { ok: false, reason: "no_market" });
});

Deno.test("no tracked link, no brand, or terms already over ⇒ skipped", () => {
  assertEquals(mapCoupon({ ...noon, web_link: "", app_link: "" }, NOW), { ok: false, reason: "no_link" });
  assertEquals(mapCoupon({ ...noon, web_link: "http://insecure.example/x" }, NOW), { ok: false, reason: "no_link" });
  assertEquals(mapCoupon({ ...noon, brand: "" , name: "" }, NOW), { ok: false, reason: "no_store" });
  assertEquals(mapCoupon({ ...noon, user_terms: "Valid until 30-12-2024" }, NOW), { ok: false, reason: "already_over" });
});

Deno.test("field names are read without case, underscores or spaces", () => {
  const m = mapCoupon({ Brand: "Noon", "Coupon Desc": "Airpods 4 at 499 AED", WebLink: noon.web_link, Countries: "UAE" }, NOW);
  assertEquals(m.ok && m.payload.store, "Noon");
});

Deno.test("countries: names, codes, lists and Arabic, only Zad's markets", () => {
  assertEquals(countriesOf("UAE, KSA"), ["AE", "SA"]);
  assertEquals(countriesOf(["Saudi Arabia", "Egypt", "India"]), ["SA", "EG"]);
  assertEquals(countriesOf([{ code: "kw" }, { name: "Qatar" }]), ["KW", "QA"]);
  assertEquals(countriesOf("مصر|الإمارات"), ["EG", "AE"]);
  assertEquals(countriesOf(null), []);
});

Deno.test("valid until: their dd-mm-yyyy, the end of that day; none or nonsense = null", () => {
  assertEquals(validUntil("Max cashback AED 50\nValid until 30-12-2024"), "2024-12-30T23:59:59.000Z");
  assertEquals(validUntil("valid till 1/2/2027"), "2027-02-01T23:59:59.000Z");
  assertEquals(validUntil("Valid on orders above AED 40"), null);
  assertEquals(validUntil("Valid until 40-13-2027"), null);
});

Deno.test("the page's coupons wherever the answer keeps them", () => {
  assertEquals(couponsOf([noon]).length, 1);
  assertEquals(couponsOf({ data: [noon, noon] }).length, 2);
  assertEquals(couponsOf({ result: { data: [noon] } }).length, 1);
  assertEquals(couponsOf({ status: "ok", coupons: [noon] }).length, 1);
  assertEquals(couponsOf({ message: "Invalid key" }), []);
  assertEquals(couponsOf(null), []);
});
