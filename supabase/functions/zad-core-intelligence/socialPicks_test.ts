import { assert, assertEquals } from "jsr:@std/assert@1";
import { isFreshPick, readSocialPick, tiktokPostedAt } from "./socialPicks.ts";

Deno.test("a pick with no price is kept, with its kind, link and capped text", () => {
  const p = readSocialPick({ deals: [], pick: { kind: "offer", title: "خصم ٣٠٪ على الخضار في كارفور", summary: "x".repeat(400), discount_percent: 30 } },
    "https://www.instagram.com/p/abc/", "2026-11-09T10:00:00Z", 120);
  assertEquals(p?.kind, "offer");
  assertEquals(p?.discount_percent, 30);
  assertEquals(p?.likes, 120);
  assertEquals(p?.summary.length, 200);
});

Deno.test("no pick, an unknown kind, or a blank title is nothing", () => {
  assertEquals(readSocialPick({ pick: null }, "https://x", null), null);
  assertEquals(readSocialPick({ pick: { kind: "contest", title: "مسابقة" } }, "https://x", null), null);
  assertEquals(readSocialPick({ pick: { kind: "recipe", title: " " } }, "https://x", null), null);
  assertEquals(readSocialPick(null, "https://x", null), null);
});

Deno.test("a percent outside 1–90 is dropped, the pick stays", () => {
  assertEquals(readSocialPick({ pick: { kind: "offer", title: "عرض كبير", discount_percent: 150 } }, "https://x", null)?.discount_percent, null);
});

Deno.test("fresh means the last two weeks; an unknown date passes", () => {
  const now = Date.parse("2026-11-10T12:00:00Z");
  assert(isFreshPick("2026-11-01T00:00:00Z", now));
  assert(!isFreshPick("2026-10-20T00:00:00Z", now));
  assert(isFreshPick(null, now));
});

Deno.test("a TikTok video's date comes from its id", () => {
  // 7163005340437482754 >> 32 = 1667758133 (2022-11-06), the shepherd's pie video.
  assertEquals(tiktokPostedAt("https://www.tiktok.com/@nadia.elsayed.official/video/7163005340437482754")?.slice(0, 10), "2022-11-06");
  assertEquals(tiktokPostedAt("https://www.tiktok.com/@x"), null);
});
