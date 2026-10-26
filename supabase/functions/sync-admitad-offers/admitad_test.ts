import { assertEquals } from "jsr:@std/assert@1";
import { admitadDate, basicHeader, mapCoupon, priceFromTitle } from "./admitad.ts";

const NOW = Date.parse("2026-10-26T12:00:00Z");
const base = {
  status: "active",
  regions: ["SA"],
  goto_link: "https://ad.admitad.com/g/abc/",
  campaign: { name: "نون" },
  date_start: "2026-10-20 00:00:00",
  date_end: "2026-10-31 23:59:59",
};

Deno.test("a titled price becomes a partner deal", () => {
  const m = mapCoupon({ ...base, name: "زيت عافية ١٫٥ لتر بـ٢٥ ريال بدل ٣٢" }, NOW);
  assertEquals(m.ok, true);
  if (!m.ok) return;
  assertEquals(m.payload.item_name, "زيت عافية 1.5 لتر");
  assertEquals(m.payload.price, 25);
  assertEquals(m.payload.price_before, 32);
  assertEquals(m.payload.country, "SA");
  assertEquals(m.payload.currency, "SAR");
  assertEquals(m.payload.source_kind, "partner");
  assertEquals(m.payload.deal_kind, "discount");
  assertEquals(m.payload.valid_until, "2026-10-31T23:59:59.000Z");
});

Deno.test("a store-wide code is skipped, not given a price", () => {
  assertEquals(mapCoupon({ ...base, name: "خصم 10% على كل الطلبات" }, NOW), { ok: false, reason: "discount_not_price" });
  assertEquals(mapCoupon({ ...base, name: "توصيل مجاني" }, NOW), { ok: false, reason: "no_price" });
  assertEquals(mapCoupon({ ...base, name: "خصم 50 ريال على 200 ريال" }, NOW), { ok: false, reason: "discount_not_price" });
});

Deno.test("«ريال» picks its market from the coupon's regions", () => {
  const qa = mapCoupon({ ...base, regions: ["QA", "EG"], name: "رز بسمتي 5 كجم 40 ريال" }, NOW);
  assertEquals(qa.ok && qa.payload.currency, "QAR");
  assertEquals(mapCoupon({ ...base, regions: ["SA", "QA"], name: "رز 40 ريال" }, NOW), { ok: false, reason: "ambiguous_market" });
  assertEquals(mapCoupon({ ...base, regions: ["EG"], name: "رز 40 ريال" }, NOW), { ok: false, reason: "no_market" });
});

Deno.test("what cannot be stored or is over is skipped", () => {
  assertEquals(mapCoupon({ ...base, name: "رز 40 SAR", status: "suspended" }, NOW).ok, false);
  assertEquals(mapCoupon({ ...base, name: "رز 40 SAR", goto_link: "http://x" }, NOW), { ok: false, reason: "no_link" });
  assertEquals(mapCoupon({ ...base, name: "رز 40 SAR", campaign: null }, NOW), { ok: false, reason: "no_store" });
  assertEquals(mapCoupon({ ...base, name: "رز 40 SAR", date_end: "2026-10-01" }, NOW), { ok: false, reason: "already_over" });
});

Deno.test("dates and the token header", () => {
  assertEquals(admitadDate("2026-10-31"), "2026-10-31T00:00:00.000Z");
  assertEquals(admitadDate("2026-10-31", true), "2026-10-31T23:59:59.000Z");
  assertEquals(admitadDate(null), null);
  assertEquals(basicHeader("id", "secret"), "Basic aWQ6c2VjcmV0");
  assertEquals("reason" in priceFromTitle("x 5 جنيه"), true);
});
