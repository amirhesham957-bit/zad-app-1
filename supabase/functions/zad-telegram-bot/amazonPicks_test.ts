import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { AMAZON_DISCLOSURE, amazonPicks, amazonPicksReply } from "./amazonPicks.ts";
import { marketFor } from "../_shared/amazonMarket.ts";
import { amazonButtonRows } from "./telegram.ts";

const noEnv = () => undefined;
const inv = [
  { item_name: "زيت", quantity: 0, low_stock_threshold: 1 },
  { item_name: "رز", quantity: 1, low_stock_threshold: 2 },
  { item_name: "سكر", quantity: 10, low_stock_threshold: 2 },
];
const shopping = [{ item_name: "حفاضات", is_purchased: false }];

Deno.test("Egypt gets amazon.eg with zad04-21, Saudi gets amazon.sa with zad0b-21", () => {
  const eg = amazonPicks(inv, [], shopping, [], marketFor("EG", noEnv));
  assert(eg.length > 0 && eg.every((p) => p.url.startsWith("https://www.amazon.eg/") && p.url.includes("tag=zad04-21")));
  const sa = amazonPicks(inv, [], shopping, [], marketFor("SA", noEnv));
  assert(sa.every((p) => p.url.startsWith("https://www.amazon.sa/") && p.url.includes("tag=zad0b-21")));
  // سر المشروع بيغلب الافتراضي.
  const secret = amazonPicks(inv, [], [], [], marketFor("EG", (n) => n === "AMAZON_ASSOCIATE_TAG_EG" ? "eg-live-21" : undefined));
  assert(secret.every((p) => p.url.includes("tag=eg-live-21")));
});

Deno.test("picks follow the need: finished first, then low, then the shopping list; plenty is not pushed", () => {
  const picks = amazonPicks(inv, [], shopping, [], marketFor("EG", noEnv));
  assertEquals(picks.map((p) => p.name), ["زيت", "رز", "حفاضات"]);
  assert(!picks.some((p) => p.name === "سكر"));
});

Deno.test("a verified ASIN links the product page; an unverified one stays a tagged search", () => {
  const catalog = [{
    id: "p1", product_name_ar: "زيت زيتون عافية", product_name_search_keywords: ["زيت"], asin: "B000TEST",
    asin_verified: true, image_url: null, average_price_sar: 30, is_active: true,
  }];
  const [oil] = amazonPicks(inv, [], [], catalog, marketFor("SA", noEnv));
  assertEquals(oil.url, "https://www.amazon.sa/dp/B000TEST?tag=zad0b-21");
  const [unverified] = amazonPicks(inv, [], [], [{ ...catalog[0], asin_verified: false }], marketFor("SA", noEnv));
  assert(unverified.url.startsWith("https://www.amazon.sa/s?k="));
});

Deno.test("at most three picks, and each becomes a button the bot accepts", () => {
  const many = Array.from({ length: 8 }, (_, i) => ({ item_name: `صنف${i}`, quantity: 0, low_stock_threshold: 1 }));
  const picks = amazonPicks(many, [], [], [], marketFor("EG", noEnv));
  assertEquals(picks.length, 3);
  assertEquals(amazonButtonRows(picks).length, 3);
});

Deno.test("the reply names the store and carries the disclosure; nothing missing says so plainly", () => {
  const picks = amazonPicks(inv, [], [], [], marketFor("EG", noEnv));
  const text = amazonPicksReply(picks, "www.amazon.eg");
  assert(text.includes("amazon.eg") && text.includes(AMAZON_DISCLOSURE));
  assert(!text.includes("https://"), "links live in the buttons, not the text");
  const empty = amazonPicksReply([], "www.amazon.sa");
  assert(empty.includes("مفيش حاجة ناقصة") && !empty.includes(AMAZON_DISCLOSURE));
});
