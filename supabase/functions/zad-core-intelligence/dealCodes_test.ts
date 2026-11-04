import { assert, assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { instagramDealPosts, postDealsPrompt, readDealCodes, videoDealsPrompt } from "./liveDeals.ts";

const NOW = new Date("2026-11-04T12:00:00Z");
const URL = "https://www.instagram.com/p/abc123/";

Deno.test("a delivery app's code with its discount is kept, upper-cased", () => {
  const codes = readDealCodes({ deals: [], codes: [{ code: "keeta30", percent: 30, amount: null, min_order: 50, valid_until: "2026-11-10" }] }, URL, NOW);
  assertEquals(codes, [{
    code: "KEETA30", discount_percent: 30, discount_amount: null, min_order: 50,
    valid_until: "2026-11-10T23:59:59.000Z", source_url: URL,
  }]);
});

Deno.test("an amount off counts when there is no percent", () => {
  const [c] = readDealCodes({ codes: [{ code: "NINJA15", amount: 15 }] }, URL, NOW);
  assertEquals([c.discount_percent, c.discount_amount], [null, 15]);
});

Deno.test("no discount, a made-up shape, a generic word, an Arabic word or an expired date are dropped", () => {
  const codes = readDealCodes({
    codes: [
      { code: "NODISCOUNT" },
      { code: "خصم", percent: 20 },
      { code: "CODE", percent: 20 },
      { code: "AB", percent: 20 },
      { code: "TOO LONG WITH SPACES", percent: 20 },
      { code: "OLD10", percent: 10, valid_until: "2026-11-01" },
      { code: "HUGE", percent: 95 },
    ],
  }, URL, NOW);
  assertEquals(codes, []);
});

Deno.test("duplicates, more than five and a non-https source give no extra codes", () => {
  const many = Array.from({ length: 8 }, (_, i) => ({ code: `CODE${i}X`, percent: 10 }));
  assertEquals(readDealCodes({ codes: many }, URL, NOW).length, 5);
  assertEquals(readDealCodes({ codes: [{ code: "AAA1", percent: 10 }, { code: "aaa1", percent: 20 }] }, URL, NOW).length, 1);
  assertEquals(readDealCodes({ codes: [{ code: "AAA1", percent: 10 }] }, "http://x", NOW), []);
  assertEquals(readDealCodes(null, URL, NOW), []);
});

Deno.test("the social prompts ask for codes, never invented", () => {
  for (const { system } of [
    postDealsPrompt("كيتا", "السعودية", "SAR", "خصم ٣٠٪ بالكود KEETA30", "2026-11-04"),
    videoDealsPrompt("نينجا", "السعودية", "SAR", "عروض نينجا", "2026-11-04"),
  ]) {
    assertStringIncludes(system, '"codes"');
    assertStringIncludes(system, "ممنوع تألّف كود");
  }
});

Deno.test("a store's own post with only a code is worth reading", () => {
  const posts = [{ caption: "استخدم كود KEETA30 على أول طلب", image_url: null }];
  assert(instagramDealPosts(posts, "كيتا", 3, true).length === 1);
});
