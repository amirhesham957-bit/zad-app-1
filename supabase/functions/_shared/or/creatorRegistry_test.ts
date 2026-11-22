import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  assertNoScrape,
  type Creator,
  listForCountry,
  normalizeHandle,
  validateCreator,
  videoCard,
} from "./creatorRegistry.ts";

const base: Creator = {
  handle: "@chef_one",
  platform: "youtube",
  country: "EG",
  kind: "chef",
  displayName: "شيف واحد",
  approved: true,
  approvedBy: "owner",
  approvedAt: "2026-11-01T00:00:00Z",
};

Deno.test("normalizeHandle: بيضيف @ ويحوّل لحروف صغيرة", () => {
  assertEquals(normalizeHandle("Chef.Name"), "@chef.name");
  assertEquals(normalizeHandle("  @Chef_1  "), "@chef_1");
});

Deno.test("normalizeHandle: يرفض الفاضي والـ@ لوحدها والحروف الغلط", () => {
  assertEquals(normalizeHandle(""), null);
  assertEquals(normalizeHandle("@"), null);
  assertEquals(normalizeHandle("bad name"), null);
  assertEquals(normalizeHandle("chef-name"), null);
  assertEquals(normalizeHandle("شيف"), null);
});

Deno.test("normalizeHandle: الحد الأقصى ٣٠ حرف (من غير @)", () => {
  assertEquals(normalizeHandle("a".repeat(30)), "@" + "a".repeat(30));
  assertEquals(normalizeHandle("a".repeat(31)), null);
});

Deno.test("validateCreator: سجل معتمد وسليم بيعدّي", () => {
  assertEquals(validateCreator(base), { ok: true, errors: [] });
});

Deno.test("validateCreator: غير المعتمد بيترفض", () => {
  const r = validateCreator({ ...base, approved: false });
  assertEquals(r.ok, false);
  assertEquals(r.errors.includes("not_approved"), true);
});

Deno.test("validateCreator: المعتمد لازم يكون ليه approvedBy وapprovedAt", () => {
  const r = validateCreator({ ...base, approvedBy: undefined, approvedAt: "مش تاريخ" });
  assertEquals(r.ok, false);
  assertEquals(r.errors.includes("approved_by_missing"), true);
  assertEquals(r.errors.includes("approved_at_invalid"), true);
});

Deno.test("validateCreator: يرفض الـhandle والبلد والمنصة الغلط", () => {
  const r = validateCreator({
    ...base,
    handle: "no good",
    country: "Egypt",
    platform: "facebook" as Creator["platform"],
  });
  assertEquals(r.ok, false);
  assertEquals(r.errors.sort(), ["country_invalid", "handle_invalid", "platform_invalid"]);
});

Deno.test("listForCountry: المعتمدين بس، والبلد والنوع بيفلتروا", () => {
  const reg: Creator[] = [
    base,
    { ...base, handle: "@unapproved", approved: false, approvedBy: undefined, approvedAt: undefined },
    { ...base, handle: "@other_country", country: "SA" },
    { ...base, handle: "@a_shop", kind: "shop" },
  ];
  assertEquals(listForCountry(reg, "EG").map((c) => c.handle), ["@chef_one", "@a_shop"]);
  assertEquals(listForCountry(reg, "eg", "shop").map((c) => c.handle), ["@a_shop"]);
});

Deno.test("listForCountry: بيشيل التكرار بـplatform+handle", () => {
  const reg: Creator[] = [base, { ...base, displayName: "نسخة تانية" }, { ...base, platform: "tiktok" }];
  const out = listForCountry(reg, "EG");
  assertEquals(out.length, 2);
  assertEquals(out.map((c) => c.platform), ["youtube", "tiktok"]);
});

Deno.test("listForCountry: الترتيب بالاسم بالعربي", () => {
  const reg: Creator[] = [
    { ...base, handle: "@c", displayName: "ياسر" },
    { ...base, handle: "@a", displayName: "أحمد" },
    { ...base, handle: "@b", displayName: "بسام" },
  ];
  assertEquals(listForCountry(reg, "EG").map((c) => c.displayName), ["أحمد", "بسام", "ياسر"]);
});

Deno.test("videoCard: يوتيوب بياخد youtube-nocookie embed", () => {
  const card = videoCard(base, { id: "abc_DEF-123", title: "وصفة" });
  assertEquals(card.embedUrl, "https://www.youtube-nocookie.com/embed/abc_DEF-123");
  assertEquals(card.watchUrl, "https://www.youtube.com/watch?v=abc_DEF-123");
  assertEquals(card.creator, base);
});

Deno.test("videoCard: id يوتيوب غلط بيترفض", () => {
  assertThrows(() => videoCard(base, { id: "short", title: "x" }), Error, "invalid_youtube_id");
  assertThrows(() => videoCard(base, { id: "has space!!", title: "x" }), Error, "invalid_youtube_id");
  assertThrows(() => videoCard(base, { id: "a".repeat(21), title: "x" }), Error, "invalid_youtube_id");
});

Deno.test("videoCard: إنستجرام وتيكتوك embedUrl = null", () => {
  const ig: Creator = { ...base, platform: "instagram", handle: "@ig_chef" };
  const tt: Creator = { ...base, platform: "tiktok", handle: "@tt_chef" };
  assertEquals(videoCard(ig, { id: "x", title: "t" }).embedUrl, null);
  assertEquals(videoCard(tt, { id: "x", title: "t" }).embedUrl, null);
  assertEquals(videoCard(ig, { id: "x", title: "t" }).watchUrl, "https://www.instagram.com/ig_chef/");
  assertEquals(videoCard(tt, { id: "x", title: "t" }).watchUrl, "https://www.tiktok.com/@tt_chef");
});

Deno.test("videoCard: العنوان بيتقص عند ١٠٠ حرف", () => {
  const card = videoCard(base, { id: "abcdef", title: "ع".repeat(150) });
  assertEquals(card.title.length, 100);
});

Deno.test("assertNoScrape: القوايم والـAPI الرسمي مسموحين، والـscrape بيتمنع", () => {
  assertNoScrape("curated_list");
  assertNoScrape("official_api");
  assertThrows(() => assertNoScrape("scrape"), Error, "scrape_forbidden");
});

Deno.test("لا يوجد 'aff' ولا 'tag=' في أي URL ناتج", () => {
  const cards = [
    videoCard(base, { id: "abcdef12", title: "t" }),
    videoCard({ ...base, platform: "instagram", handle: "@ig" }, { id: "abcdef12", title: "t" }),
    videoCard({ ...base, platform: "tiktok", handle: "@tt" }, { id: "abcdef12", title: "t" }),
  ];
  for (const card of cards) {
    const urls = [card.watchUrl, card.embedUrl ?? ""];
    for (const u of urls) {
      assertEquals(u.includes("aff"), false);
      assertEquals(u.includes("tag="), false);
    }
  }
});
