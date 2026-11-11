import { assertEquals } from "jsr:@std/assert@1";
import { cycleDays, priorCycleDays, purchaseDaysByItem, restockKey, restockVerdict, habitCycleDays, DUE_AT, dueAfterDays } from "./restockCycle.ts";

const NOW = Date.parse("2026-11-06T09:00:00Z");
const ago = (days: number) => new Date(NOW - days * 86_400_000).toISOString();

Deno.test("owner 6/11: what was bought this morning is not missing tonight", () => {
  for (const [name, category] of [
    ["سمن شيراتون Pure Butter Oil", "الألبان"], ["ستر باور مسحوق يدوي 1 كجم", "العناية"],
    ["راديسون حلاوة 500 جم", "البقالة"], ["فيبكس رول أون حريمي ورجالي 50 مل", "العناية"],
  ]) {
    const v = restockVerdict({ name, category, quantity: 1, threshold: 2, purchaseDays: [ago(0.6)] }, NOW);
    assertEquals(v.due, false, name);
    assertEquals(v.reason, "fresh");
  }
});

Deno.test("carrier bags are never a shortage", () => {
  assertEquals(restockVerdict({ name: "شنطة كاشير", quantity: 0, purchaseDays: [ago(30)] }, NOW).reason, "not_restocked");
});

Deno.test("bread comes back after two days, sugar after a month", () => {
  assertEquals(restockVerdict({ name: "عيش بلدي", quantity: 5, purchaseDays: [ago(2)] }, NOW).due, true);
  assertEquals(restockVerdict({ name: "سكر", quantity: 1, purchaseDays: [ago(10)] }, NOW).due, false);
  assertEquals(restockVerdict({ name: "سكر", quantity: 1, purchaseDays: [ago(27)] }, NOW).due, true);
});

Deno.test("empty is always missing, unless the customer said it is occasional", () => {
  assertEquals(restockVerdict({ name: "زيت", quantity: 0, purchaseDays: [ago(1)] }, NOW).reason, "empty");
  assertEquals(restockVerdict({ name: "رنجة", quantity: 0, restockMode: "occasional", purchaseDays: [] }, NOW).due, false);
});

Deno.test("used up by hand past half its cycle is missing", () => {
  assertEquals(restockVerdict({ name: "زيت", quantity: 0.5, threshold: 1, purchaseDays: [ago(16)] }, NOW).reason, "used_up");
  assertEquals(restockVerdict({ name: "زيت", quantity: 0.5, threshold: 1, purchaseDays: [ago(5)] }, NOW).due, false);
});

Deno.test("no purchase history keeps the old threshold rule", () => {
  assertEquals(restockVerdict({ name: "مكرونة", quantity: 1, threshold: 2, purchaseDays: [] }, NOW).reason, "threshold");
  assertEquals(restockVerdict({ name: "مكرونة", quantity: 5, threshold: 2, purchaseDays: [] }, NOW).reason, "stocked");
});

Deno.test("the home's own rhythm replaces the starting guess", () => {
  // بيشتري زيت كل ١٠ أيام مش كل شهر.
  assertEquals(cycleDays(30, ["2026-10-01", "2026-10-11", "2026-10-21", "2026-10-31"]), 10);
  // مسافة واحدة: نص بنص مع البداية.
  assertEquals(cycleDays(30, ["2026-10-01", "2026-10-11"]), 20);
  // نفس اليوم مرتين = فاتورة واحدة.
  assertEquals(cycleDays(30, ["2026-10-01T10:00:00Z", "2026-10-01T18:00:00Z"]), 30);
  // شرا كل شهرين بيبقى دورته شهرين — مابيتعرضش بعد أسبوع.
  const herring = ["2026-07-01", "2026-09-01", "2026-11-01"];
  assertEquals(restockVerdict({ name: "رنجة", quantity: 1, purchaseDays: herring }, NOW).due, false);
});

Deno.test("priors by name first, then category", () => {
  assertEquals(priorCycleDays("حليب جهينة"), 4);
  assertEquals(priorCycleDays("لبن"), 4);
  assertEquals(priorCycleDays("جبنة رومي"), 10);
  assertEquals(priorCycleDays("حاجة غريبة", "العناية"), 45);
  assertEquals(priorCycleDays("حاجة غريبة"), 21);
});

Deno.test("purchase days are grouped by normalized name", () => {
  const m = purchaseDaysByItem([
    { item_name: "سمن شيراتون", observed_at: ago(1) }, { item_name: "سمن  شيراتون ".trim(), observed_at: ago(31) },
    { item_name: null, observed_at: ago(1) },
  ]);
  assertEquals(m.get(restockKey("سمن شيراتون"))?.length, 2);
});

Deno.test("the customer's own cycle beats the guess and the learned one", () => {
  // «الزيت عندي كل أسبوعين»: اتشرى من ١٢ يوم ⇒ مستحق (١٢ ≥ ١٤×٠٫٨٥)، من غير التصحيح كان لسه (الدورة ٣٠).
  assertEquals(restockVerdict({ name: "زيت", quantity: 1, purchaseDays: [ago(12)], cycleOverride: 14 }, NOW).due, true);
  assertEquals(restockVerdict({ name: "زيت", quantity: 1, purchaseDays: [ago(12)] }, NOW).due, false);
  // قيمة غلط بتتجاهل.
  assertEquals(restockVerdict({ name: "زيت", quantity: 1, purchaseDays: [ago(12)], cycleOverride: 0 }, NOW).cycleDays, 30);
});

Deno.test("a habit needs three different purchase days", () => {
  assertEquals(habitCycleDays(["2026-10-01", "2026-10-16"]), null);
  assertEquals(habitCycleDays(["2026-10-01T09:00:00Z", "2026-10-01T18:00:00Z", "2026-10-16"]), null);
  assertEquals(habitCycleDays(["2026-10-01", "2026-10-16", "2026-10-31"]), 15);
});

Deno.test("a long cycle warns three days before it runs out, not earlier", () => {
  // زيت: دورة ٣٠ يوم.
  assertEquals(restockVerdict({ name: "زيت", quantity: 3, purchaseDays: [ago(26)] }, NOW).due, false);
  assertEquals(restockVerdict({ name: "زيت", quantity: 3, purchaseDays: [ago(27)] }, NOW).due, true);
  // منظف: دورة طويلة، ولا هو قبلها بأسبوع.
  assertEquals(restockVerdict({ name: "زيت", quantity: 3, purchaseDays: [ago(50)], cycleOverride: 60 }, NOW).due, false);
  assertEquals(restockVerdict({ name: "زيت", quantity: 3, purchaseDays: [ago(57)], cycleOverride: 60 }, NOW).due, true);
});

Deno.test("a short cycle keeps its share: three days ahead would mean always", () => {
  assertEquals(dueAfterDays(2), 2 * DUE_AT);
  assertEquals(dueAfterDays(10), 10 * DUE_AT);
  assertEquals(dueAfterDays(30), 27);
});

// المالك ١١/١١: «ضرورية لازم متنقصش في البيت وتتجاب أول بأول».
Deno.test("essential: bought on 3 days with a short cycle is learned as essential and comes due earlier", () => {
  const now = Date.parse("2026-11-11T12:00:00Z");
  const ago = (d: number) => new Date(now - d * 86_400_000).toISOString();
  // لبن كل ٤ أيام، آخر مرة من ٣ أيام: ٣ ≥ ٤×٠٫٧ (٢٫٨) بس أقل من ٤×٠٫٨٥ (٣٫٤).
  const milk = restockVerdict({ name: "حليب", quantity: 2, purchaseDays: [ago(11), ago(7), ago(3)] }, now);
  assertEquals(milk.essential, true);
  assertEquals(milk.due, true);
  // نفس الصنف بشرا واحد بس: مش متعلّم أساسي لسه، فبيستنى الـ٨٥٪.
  const once = restockVerdict({ name: "حليب", quantity: 2, purchaseDays: [ago(3)] }, now);
  assertEquals(once.essential, false);
  assertEquals(once.due, false);
});

Deno.test("essential: a monthly item is never essential by itself, but the customer's «دي أساسية» makes it one", () => {
  const now = Date.parse("2026-11-11T12:00:00Z");
  const ago = (d: number) => new Date(now - d * 86_400_000).toISOString();
  const oil = restockVerdict({ name: "زيت", quantity: 1, purchaseDays: [ago(90), ago(60), ago(30)] }, now);
  assertEquals(oil.essential, false);
  assertEquals(restockVerdict({ name: "زيت", quantity: 1, restockMode: "staple", purchaseDays: [ago(5)] }, now).essential, true);
  assertEquals(restockVerdict({ name: "رنجة", quantity: 1, restockMode: "occasional", purchaseDays: [ago(5), ago(3), ago(1)] }, now).essential, false);
});

Deno.test("essential: the early warning still never comes more than 3 days before it runs out", () => {
  assertEquals(dueAfterDays(3, true), 3 * 0.7);
  assertEquals(dueAfterDays(14, true), 11);
});
