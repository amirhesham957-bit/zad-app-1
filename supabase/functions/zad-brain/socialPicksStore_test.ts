import { assertEquals } from "jsr:@std/assert@1";
import { socialPickRows } from "./socialPicksStore.ts";
import { matchChatPicks, describeChatDeals, type ChatPickRow } from "./chatDeals.ts";
import { linkForms } from "./knownLinks.ts";

const t = { country: "EG", store: "كارفور" };

Deno.test("pick rows: only https links with a known kind and a title", () => {
  const rows = socialPickRows(t, [
    { kind: "offer", title: "خصم ٣٠٪", summary: "على الخضار", discount_percent: 30, source_url: "https://www.tiktok.com/@c/video/1", likes: 80, posted_at: "2026-11-09T00:00:00Z" },
    { kind: "contest", title: "مسابقة", source_url: "https://x.com/1" },
    { kind: "offer", title: "عرض", source_url: "http://insecure" },
  ], "tiktok");
  assertEquals(rows.length, 1);
  assertEquals(rows[0].country, "EG");
  assertEquals(rows[0].platform, "tiktok");
  assertEquals(rows[0].discount_percent, 30);
});

const pick = (o: Partial<ChatPickRow>): ChatPickRow => ({
  platform: "instagram", kind: "offer", store: "كارفور", title: "خصم على الزيت", summary: "", discount_percent: null, likes: 10,
  source_url: "https://www.instagram.com/p/a/", ...o,
});

Deno.test("chat picks: by store, by item, most liked first", () => {
  const rows = [pick({ likes: 5 }), pick({ store: "سبينيس", likes: 900 }), pick({ title: "وصفة كشري", kind: "recipe", likes: 50 })];
  assertEquals(matchChatPicks(rows, "كارفور", "").length, 2);
  assertEquals(matchChatPicks(rows, "", "زيت").length, 2);
  assertEquals(matchChatPicks(rows, "", "")[0].store, "سبينيس");
});

Deno.test("picks alone still make an answer, with their links", () => {
  const text = describeChatDeals({ deals: [], codes: [], picks: [pick({})] }, "", "");
  assertEquals(text.includes("https://www.instagram.com/p/a/"), true);
  assertEquals(text.includes("مفيش عروض"), false);
});

Deno.test("a link is looked up with and without its trailing slash", () => {
  assertEquals(linkForms("https://www.instagram.com/p/a/"), ["https://www.instagram.com/p/a", "https://www.instagram.com/p/a/"]);
});

import { videosForChat } from "./videoLinks.ts";

Deno.test("an Instagram link we stored stays in the reply; one the model wrote is dropped", async () => {
  const reply = "عرض كارفور: https://www.instagram.com/p/real/\nوده كمان: https://www.instagram.com/p/fake/";
  const out = await videosForChat(reply, {
    fetcher: (() => Promise.resolve(new Response("", { status: 404 }))) as typeof fetch,
    isKnownLink: (u) => Promise.resolve(u.includes("/real")),
  });
  assertEquals(out.includes("/p/real/"), true);
  assertEquals(out.includes("/p/fake/"), false);
});

Deno.test("weekTrendRows: هبة تيك توك بنوع trend، والمحل لكل هبة (أو null)، والرابط لازم فيديو تيك توك", async () => {
  const { weekTrendRows } = await import("./socialPicksStore.ts");
  const rows = weekTrendRows("EG", [
    { source_url: "https://www.tiktok.com/@chef.a/video/7400000000000000000", title: "صاحي كيو", summary: "ساندوتش", store: "كيو ماركت", posted_at: "2026-11-12T00:00:00Z" },
    { source_url: "https://www.tiktok.com/@b/video/7400000000000000001", title: "كنافة دبي", summary: "", store: null },
    { source_url: "https://evil.example/x", title: "رابط غريب" },
    { source_url: "https://www.tiktok.com/@c/video/7400000000000000002?x=1", title: "فيه query" },
    { source_url: "https://www.tiktok.com/@d/video/7400000000000000003", title: "x" },
  ]);
  assertEquals(rows.map((r) => [r.kind, r.platform, r.title, r.store, r.store_key === null]), [
    ["trend", "tiktok", "صاحي كيو", "كيو ماركت", false],
    ["trend", "tiktok", "كنافة دبي", null, true],
  ]);
  assertEquals(weekTrendRows("egypt", [{ source_url: "https://www.tiktok.com/@a/video/1", title: "abc" }]), []);
});
