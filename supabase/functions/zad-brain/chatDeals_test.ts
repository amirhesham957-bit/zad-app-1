import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { type ChatCodeRow, type ChatDealRow, describeChatDeals, matchChatDeals } from "./chatDeals.ts";
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
