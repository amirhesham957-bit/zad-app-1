import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import {
  type ChatCodeRow,
  type ChatDealRow,
  describeChatDeals,
  matchChatDeals,
  matchSheinOffers,
  type SheinOfferRow,
} from "./chatDeals.ts";
import { codeStoreKey } from "./dealCodes.ts";
import { intentToolHints } from "./specialists.ts";

const deal = (store: string, item: string, price: number, before: number | null, url = "https://www.instagram.com/p/a/"): ChatDealRow =>
  ({ store, item_name: item, price, price_before: before, currency: "SAR", source_kind: "instagram", source_url: url, valid_until: "2026-11-20" });
const code = (store: string, c: string, pct: number): ChatCodeRow =>
  ({ store, store_key: codeStoreKey(store), code: c, discount_percent: pct, discount_amount: null, currency: "SAR", min_order: 50, valid_until: null, source_url: "https://www.instagram.com/reel/r/" });

const DEALS = [
  deal("كارفور", "زيت عافية 1.5 لتر", 25, 35), deal("بنده", "زيت عافية 1.5 لتر", 27, 30),
  deal("كيتا", "وجبة برجر", 19, 39), deal("كارفور", "أرز بسمتي 5 كيلو", 60, 70), deal("كارفور", "سكر 1 كيلو", 4, 5),
];
const CODES = [code("كيتا", "KEETA30", 30), code("نينجا", "NINJA10", 10)];

Deno.test("find_deals: by store, by item, or the strongest in the country — biggest saving first", () => {
  assertEquals(matchChatDeals(DEALS, CODES, "كيتا", "").deals.map((d) => d.item_name), ["وجبة برجر"]);
  assertEquals(matchChatDeals(DEALS, CODES, "كيتا", "").codes.map((c) => c.code), ["KEETA30"]);
  assertEquals(matchChatDeals(DEALS, CODES, "", "زيت").deals.map((d) => d.store), ["كارفور", "بنده"]);
  const all = matchChatDeals(DEALS, CODES, "", "");
  assertEquals(all.deals[0].item_name, "وجبة برجر"); // 51%
  assertEquals(all.deals.filter((d) => d.store === "كارفور").length, 2); // a store twice at most when none was asked
  assertEquals(all.codes.length, 2);
});

Deno.test("find_deals: the answer lists prices and links first, and never lets the budget withhold them", () => {
  const text = describeChatDeals(matchChatDeals(DEALS, CODES, "كيتا", ""), "كيتا", "");
  assertStringIncludes(text, "وجبة برجر — كيتا: 19 SAR بدل 39 (خصم 51٪)");
  assertStringIncludes(text, "https://www.instagram.com/p/a/");
  assertStringIncludes(text, "كود KEETA30 — كيتا: 30٪ على طلب 50 أو أكتر");
  assertStringIncludes(text, "الميزانية مش سبب");
  assertStringIncludes(describeChatDeals({ deals: [], codes: [] }, "هرفي", ""), "مفيش عروض متخزنة شغالة في هرفي");
});

Deno.test("find_deals is offered when he asks for offers or a code — not on a bank deduction", () => {
  for (const m of ["هاتلي عروض كيتا", "فيه عروض إيه النهارده؟", "دورلي على عرض على الزيت", "في كود خصم لطلبات؟", "عايز كوبون نون"]) {
    assert(intentToolHints(m).includes("find_deals"), m);
  }
  for (const m of ["اتخصم مني 50 جنيه", "مرحبا", "صرفت 200 على الغدا"]) {
    assert(!intentToolHints(m).includes("find_deals"), m);
  }
});

Deno.test("find_deals: «المقاضي» asks for everything, not an item of that name", () => {
  assertEquals(matchChatDeals(DEALS, CODES, "", "المقاضي").deals.length, matchChatDeals(DEALS, CODES, "", "").deals.length);
  assertEquals(matchChatDeals(DEALS, CODES, "", "خزين البيت").deals.length > 0, true);
});

const ONE = "https://onelink.shein.com/60/67x9gydalfpz?ismg_ol=4TYBWTPjnSB_01_KOC-C";
const shein = (title: string, url = ONE, code: string | null = null): SheinOfferRow =>
  ({ title, affiliate_url: url, coupon_code: code, category: "fashion_home" });
const SHEIN = [
  shein("فستان صيفي مشجر"), shein("طقم ولادي أطفال قطن"), shein("مفارش سرير ٦ قطع"),
  shein("بلوزة", "https://ar.shein.com/p-1.html?aff_id=4559428113"), // not a dashboard link
];

Deno.test("find_deals: SHEIN answers fashion, kids and home — not groceries, not another store", () => {
  assertEquals(matchSheinOffers(SHEIN, "", "لبس أطفال").map((o) => o.title)[0], "طقم ولادي أطفال قطن");
  assertEquals(matchSheinOffers(SHEIN, "شي ان", "").length, 3);
  assertEquals(matchSheinOffers(SHEIN, "", "").length, 3);
  assertEquals(matchSheinOffers(SHEIN, "", "زيت"), []);
  assertEquals(matchSheinOffers(SHEIN, "كارفور", "فستان"), []);
  // A link that is not SHEIN's dashboard link never reaches the customer.
  assert(!matchSheinOffers(SHEIN, "shein", "").some((o) => o.affiliate_url.includes("aff_id")));
});

Deno.test("find_deals: a SHEIN link goes out letter for letter, with the commission said and no referral code", () => {
  const out = describeChatDeals({ deals: [], codes: [], shein: [shein("فستان صيفي", ONE, "SUMMER10")] }, "", "فستان");
  assertStringIncludes(out, ONE);
  assertStringIncludes(out, "بالحرف");
  assertStringIncludes(out, "عمولة");
  assertStringIncludes(out, "كود خصم للمشتري: SUMMER10");
  assert(!out.includes("B8U6U"));
});

Deno.test("find_deals is offered on SHEIN or clothes and home asked for", () => {
  for (const m of ["عايز فستان من شي ان", "عندك حاجة من shein؟", "عايزة لبس للعيال", "محتاج مفارش جديدة"]) {
    assert(intentToolHints(m).includes("find_deals"), m);
  }
  assert(!intentToolHints("لبست الجاكيت النهارده").includes("find_deals"));
});
