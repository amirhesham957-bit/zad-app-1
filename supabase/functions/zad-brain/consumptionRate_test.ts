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

// ١١/١١: حساب المالك اتسأل ٨ مرات في أسبوع عن حلاوة ومسحوق ورول أون وسمن (كمية ١ كل واحد) ولا مرة عن اللبن،
// مع إن الملف السلوكي كان عارف إن اللبن بيتشرى كل ٣ أيام.
const NOW = Date.parse("2026-11-11T19:30:00Z");
const ago = (d: number) => new Date(NOW - d * 86_400_000).toISOString();

Deno.test("checkInPriority: milk the home buys every 3 days is due; halva bought 6 days ago is not", () => {
  const milk = checkInPriority({ name: "حليب", quantity: 3.5, category: "الألبان" }, null, [ago(9), ago(6), ago(3)], NOW)!;
  const halva = checkInPriority({ name: "راديسون حلاوة 500 جم", quantity: 1, category: "البقالة" }, null, [ago(6)], NOW)!;
  const powder = checkInPriority({ name: "ستر باور مسحوق يدوي 1 كجم", quantity: 1, category: "العناية" }, null, [ago(6)], NOW)!;
  assertEquals(milk >= 1, true);
  assertEquals(halva < 1, true);
  assertEquals(powder < 1, true);
});

Deno.test("checkInPriority: the home's own rhythm beats the kind — oil bought weekly is asked after a week", () => {
  const weekly = checkInPriority({ name: "زيت", quantity: 1, category: "البقالة" }, null, [ago(22), ago(15), ago(8)], NOW)!;
  const fresh = checkInPriority({ name: "زيت", quantity: 1, category: "البقالة" }, null, [ago(8)], NOW)!;
  assertEquals(weekly >= 1, true);
  assertEquals(fresh < 1, true);
});

Deno.test("checkInPriority: bags, occasional items, empty items and items bought today are never asked", () => {
  assertEquals(checkInPriority({ name: "شنطة كاشير", quantity: 4, category: "أخرى" }, null, [ago(40)], NOW), null);
  assertEquals(checkInPriority({ name: "رنجة", quantity: 1, restockMode: "occasional" }, null, [ago(90)], NOW), null);
  assertEquals(checkInPriority({ name: "حليب", quantity: 0 }, null, [ago(40)], NOW), null);
  assertEquals(checkInPriority({ name: "حليب", quantity: 2 }, null, [ago(0.1)], NOW), null);
});

Deno.test("checkInPriority: the customer's own cycle wins, and a known rate wins over the cycle", () => {
  // «الزيت عندي كل أسبوعين».
  assertEquals(checkInPriority({ name: "زيت", quantity: 1, cycleOverride: 14 }, null, [ago(13)], NOW)! >= 1, true);
  const water = checkInPriority({ name: "مياه", quantity: 4 }, 2, [ago(1)], NOW)!; // يومين فاضلين
  const oil = checkInPriority({ name: "زيت", quantity: 4 }, 0.5, [ago(1)], NOW)!; // ٨ أيام
  assertEquals(water >= 1, true);
  assertEquals(oil < 1, true);
  assertEquals(water > oil, true);
});
