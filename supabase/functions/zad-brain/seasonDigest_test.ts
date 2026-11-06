import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { type DigestCodeRow, type DigestDealRow, digestKey, digestPhoto, pickDigest, pickDigestCodes, pickHomeDeals } from "./seasonDigest.ts";

const row = (o: Partial<DigestDealRow>): DigestDealRow => ({
  store: "كارفور", item_name: "زيت عافية 1.5 لتر", price: 30, price_before: 40, currency: "EGP",
  source_kind: "youtube", source_url: "https://www.youtube.com/watch?v=abc123XYZ", valid_until: null, ...o,
});

Deno.test("only what the house needs, its stores' real discounts, or a fire deal on what it buys", () => {
  const rows = [
    row({}), // need: زيت
    row({ item_name: "شيبسي", price: 10, price_before: 11, store: "كازيون" }), // 9%، مش محتاجه
    row({ item_name: "جبنة رومي", price: 50, price_before: 80, store: "كازيون" }), // 37% في محله
    row({ item_name: "مكرونة", price: 5, price_before: 10, store: "بيم" }), // 50% واتشرت قبل كده
  ];
  const cards = pickDigest(rows, ["زيت"], ["Kazyon", "كازيون"], ["مكرونة"], new Set());
  assertEquals(cards.map((c) => [c.item, c.why]), [
    ["زيت عافية 1.5 لتر", "need"],
    ["جبنة رومي", "favorite"],
    ["مكرونة", "fire"],
  ]);
  assertEquals(cards[0].photo, "https://i.ytimg.com/vi/abc123XYZ/hqdefault.jpg");
  assertEquals(cards[0].saving, 25);
});

Deno.test("a deal sent this season is not sent again; a new price is a new deal", () => {
  const sent = new Set([digestKey("كارفور", "زيت عافية 1.5 لتر", 30)]);
  assertEquals(pickDigest([row({})], ["زيت"], [], [], sent), []);
  assertEquals(pickDigest([row({ price: 28 })], ["زيت"], [], [], sent).length, 1);
});

Deno.test("one item once, two cards per store at most, four in all", () => {
  const rows = ["زيت", "زيت ذرة", "سكر", "رز", "شاي", "لبن"].map((item, i) =>
    row({ item_name: item, price: 10 + i, store: i < 3 ? "كارفور" : `محل ${i}` }));
  const cards = pickDigest(rows, ["زيت", "سكر", "رز", "شاي", "لبن"], [], [], new Set());
  assertEquals(cards.length, 4);
  assertEquals(cards.filter((c) => c.store === "كارفور").length, 2);
});

Deno.test("no picture but a YouTube thumbnail by id", () => {
  assertEquals(digestPhoto("instagram", "https://www.instagram.com/p/x/"), null);
  assertEquals(digestPhoto("youtube", "https://evil.example/watch?v=abc123XYZ"), null);
});

Deno.test("codes only for the house's own apps, not sent before", () => {
  const codes = [
    { store: "كيتا", store_key: "keeta", code: "KEETA30", discount_percent: 30, discount_amount: null, currency: "SAR", min_order: null, valid_until: null, source_kind: "instagram", source_url: "https://www.instagram.com/p/x/" },
    { store: "جاهز", store_key: "jahez", code: "JAHEZ10", discount_percent: 10, discount_amount: null, currency: "SAR", min_order: null, valid_until: null, source_kind: "instagram", source_url: "https://www.instagram.com/p/y/" },
  ];
  assertEquals(pickDigestCodes(codes, ["Keeta"], new Set()).map((c) => c.code), ["KEETA30"]);
  assertEquals(pickDigestCodes(codes, ["Keeta"], new Set(["code|keeta|KEETA30"])), []);
});

const code = (o: Partial<DigestCodeRow>): DigestCodeRow => ({
  store: "كارفور", store_key: "كارفور", code: "SAVE10", discount_percent: 10, discount_amount: null, currency: null,
  min_order: null, valid_until: null, source_kind: "instagram", source_url: "https://www.instagram.com/p/x", ...o,
});

Deno.test("home strip: the need first, each card with its own store's code, codes for the cards' stores", () => {
  const out = pickHomeDeals({
    broke: false,
    needs: ["لبن"],
    favorites: [],
    bought: [],
    deals: [row({ item_name: "لبن جهينة 1 لتر", price: 35, price_before: 40 }), row({ item_name: "شيبسي", store: "بيم" })],
    codes: [code({}), code({ store: "طلبات", store_key: "طلبات", code: "TB5" })],
  });
  assertEquals(out.cards.map((c) => [c.item, c.why, c.code?.code]), [["لبن جهينة 1 لتر", "need", "SAVE10"]]);
  assertEquals(out.cards[0].code?.percent, 10);
  assertEquals(out.codes.map((c) => c.code), ["SAVE10"]);
});

Deno.test("home strip in broke mode: only what the home needs, no codes, no store deals", () => {
  const out = pickHomeDeals({
    broke: true,
    needs: ["لبن"],
    favorites: ["بيم"],
    bought: ["مكرونة"],
    deals: [
      row({ item_name: "لبن جهينة 1 لتر", price: 35, price_before: 40 }),
      row({ item_name: "جبنة", store: "بيم", price: 50, price_before: 80 }),
      row({ item_name: "مكرونة", store: "بيم", price: 5, price_before: 10 }),
    ],
    codes: [code({})],
  });
  assertEquals(out.cards.map((c) => [c.item, c.code]), [["لبن جهينة 1 لتر", null]]);
  assertEquals(out.codes, []);
});

Deno.test("nothing personal ⇒ the season's strongest real discounts, pictures first, never a deal without a before-price", async () => {
  const { pickTopDeals } = await import("./seasonDigest.ts");
  const top = pickTopDeals([
    row({ item_name: "ارز غدير 5 ك", store: "خير زمان", price: 125, price_before: 150, source_kind: "youtube" }), // 17% بصورة
    row({ item_name: "رمان 1 كيلو", store: "مترو", price: 44.99, price_before: 64.99, source_kind: "search", source_url: "https://x.example/a" }), // 31%
    row({ item_name: "لحم", store: "أولاد رجب", price: 399, price_before: null }), // مفيش سعر قبل
    row({ item_name: "قهوة", store: "بيم", price: 95, price_before: 100 }), // 5%
  ], new Set());
  assertEquals(top.map((c) => [c.item, c.why, c.saving]), [["ارز غدير 5 ك", "top", 17], ["رمان 1 كيلو", "top", 31]]);
});
