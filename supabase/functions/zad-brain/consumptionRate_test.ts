import { assertEquals } from "jsr:@std/assert@1";
import { checkInPriority, needsCheckIn, rateConfidence } from "../_shared/consumptionRate.ts";

// الفجوة ٧: لبن ١ ← ٠ في ١٧.٦ ساعة (٢٠٢٦-٠٨-١٧) بقى ليه معدل تقريبي ١.٣٦ في اليوم.
Deno.test("rateConfidence: one purchase cycle is an approximate rate, not an unknown one", () => {
  assertEquals(rateConfidence(1.36, false), "approximate");
  assertEquals(rateConfidence(0.9, true), "known");
  assertEquals(rateConfidence(null, false), "unknown");
  assertEquals(rateConfidence(0, true), "unknown");
});

Deno.test("needsCheckIn: an approximate rate asks before the item runs out", () => {
  // ٢ علب بمعدل ١.٣٦ في اليوم = أقل من يومين → يسأل، حتى والمعدل تقريبي.
  assertEquals(needsCheckIn(3, 1, 1.36), false);
  assertEquals(needsCheckIn(2.5, 1, 1.36), true);
  assertEquals(needsCheckIn(10, null, 0.13), false);
  assertEquals(needsCheckIn(2, null, null), true, "under the default threshold of 2");
  assertEquals(needsCheckIn(5, 1, null), false, "no rate, above the threshold");
});

Deno.test("needsCheckIn: an item already at zero is not asked about (2026-11-01)", () => {
  // «مياه نستله» was asked «لسه عندك؟» three times at 0. Gone is known; the list holds it.
  assertEquals(needsCheckIn(0, null, null), false);
  assertEquals(needsCheckIn(0, 2, 1), false);
  assertEquals(needsCheckIn(-1, 2, null), false);
  assertEquals(needsCheckIn(0.2, null, null), true, "a little left is still worth asking");
});

Deno.test("needsCheckIn: the house's rate decides when it is known, and a row added in the last day is not asked about (2026-11-04)", () => {
  const now = Date.parse("2026-11-04T12:00:00Z");
  // Milk added at 1.5 with the default threshold of 2: not «is it finished?» a minute later.
  assertEquals(needsCheckIn(1.5, 2, null, "2026-11-04T11:59:00Z", now), false);
  assertEquals(needsCheckIn(1.5, 2, null, "2026-11-02T10:00:00Z", now), true, "two days later the threshold applies");
  // Two bottles a day: one bottle under a threshold of 2 is still asked, ten under a threshold of 12 is not.
  assertEquals(needsCheckIn(10, 12, 2, null, now), false);
  assertEquals(needsCheckIn(4, 1, 2, "2026-11-04T11:59:00Z", now), true, "the rate decides even on the first day");
});

// ١١/١١: حساب المالك اتسأل ٨ مرات في أسبوع عن حلاوة ومسحوق ورول أون وسمن (كمية ١ كل واحد) ولا مرة عن اللبن.
Deno.test("checkInPriority: milk after 3 days is due, a jar of halva after 6 days is not", () => {
  const now = Date.parse("2026-11-11T19:30:00Z");
  const daysAgo = (d: number) => new Date(now - d * 86_400_000).toISOString();
  const milk = checkInPriority("حليب", 3.5, "الألبان", null, daysAgo(3), now)!;
  const halva = checkInPriority("راديسون حلاوة 500 جم", 1, "البقالة", null, daysAgo(6), now)!;
  const powder = checkInPriority("ستر باور مسحوق يدوي 1 كجم", 1, "العناية", null, daysAgo(6), now)!;
  assertEquals(milk >= 1, true);
  assertEquals(halva < 1, true);
  assertEquals(powder < 1, true);
});

Deno.test("checkInPriority: the name beats the category — toast filed under groceries goes in days", () => {
  const now = Date.parse("2026-11-11T19:30:00Z");
  const fourDays = new Date(now - 4 * 86_400_000).toISOString();
  assertEquals(checkInPriority("توست بني مربع من برنش، 425 جرام", 2, "البقالة", null, fourDays, now)! >= 1, true);
  assertEquals(checkInPriority("خل طبيعي الطاووس - ١ لتر", 1, "البقالة", null, fourDays, now)! < 1, true);
});

Deno.test("checkInPriority: bags, empty items and items seen today are never asked", () => {
  const now = Date.parse("2026-11-11T19:30:00Z");
  const old = new Date(now - 40 * 86_400_000).toISOString();
  assertEquals(checkInPriority("شنطة كاشير", 4, "أخرى", null, old, now), null);
  assertEquals(checkInPriority("حليب", 0, "الألبان", null, old, now), null);
  assertEquals(checkInPriority("حليب", 2, "الألبان", null, new Date(now - 3600_000).toISOString(), now), null);
});

Deno.test("checkInPriority: a household rate wins, and what runs out sooner ranks higher", () => {
  const now = Date.parse("2026-11-11T19:30:00Z");
  const yesterday = new Date(now - 86_400_000).toISOString();
  const water = checkInPriority("مياه", 4, "المشروبات", 2, yesterday, now)!; // ٢ يوم فاضلين
  const oil = checkInPriority("زيت", 4, "البقالة", 0.5, yesterday, now)!; // ٨ أيام
  assertEquals(water >= 1, true);
  assertEquals(oil < 1, true);
  assertEquals(water > oil, true);
});
