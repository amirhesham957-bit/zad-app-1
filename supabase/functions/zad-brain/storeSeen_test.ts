import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { buildStoreArrivalMessage, cheaperHereItems, normalizeForPerson, sameStore, seenHereItems, storeKey } from "./shared.ts";

Deno.test("storeKey drops the generic words, Arabic and Latin", () => {
  assertEquals(storeKey("كارفور ماركت"), "كارفور");
  assertEquals(storeKey("Carrefour Express - Maadi"), "carrefour maadi");
  assertEquals(storeKey("سوبر ماركت خير زمان"), "خير زمان");
});

Deno.test("sameStore: one name inside the other after tidying, 3 letters at least", () => {
  assertEquals(sameStore("كارفور ماركت", "كارفور"), true);
  assertEquals(sameStore("هايبر وان", "وان"), true);
  assertEquals(sameStore("كارفور", "سعودي ماركت"), false);
  assertEquals(sameStore("ماركت", "سوبر ماركت"), false, "nothing left to compare");
  assertEquals(sameStore("ab", "abc"), false);
});

Deno.test("seenHereItems: a missing item reported at a same-named store, newest, within 72h", () => {
  const now = Date.parse("2026-09-29T12:00:00Z");
  const reports = [
    { item_name: "لبن جهينة ١ لتر", store_name: "كارفور ماركت", timestamp: "2026-09-29T09:00:00Z" },
    { item_name: "لبن", store_name: "كارفور", timestamp: "2026-09-28T12:00:00Z" },
    { item_name: "عيش", store_name: "خير زمان", timestamp: "2026-09-29T11:00:00Z" },
    { item_name: "رز", store_name: "كارفور", timestamp: "2026-09-25T12:00:00Z" },
    { item_name: null, store_name: "كارفور", timestamp: "2026-09-29T11:00:00Z" },
  ];
  const seen = seenHereItems(reports, "كارفور", ["لبن", "عيش", "رز"], now);
  assertEquals(seen, [{ item: "لبن", hours: 3 }], "عيش is another store; رز is 4 days old");
});

Deno.test("the arrival message says where it was seen, and only when it was", () => {
  const withSeen = buildStoreArrivalMessage({
    storeName: "كارفور", category: "supermarket", shopping: ["لبن"], lowStock: [], clientHints: [],
    seenHere: [{ item: "لبن", hours: 3 }],
  });
  assertStringIncludes(withSeen!.body, "👀 اتشاف في محل بنفس الاسم");
  assertStringIncludes(withSeen!.body, "لبن (من 3 ساعات)");
  const without = buildStoreArrivalMessage({
    storeName: "كارفور", category: "supermarket", shopping: ["لبن"], lowStock: [], clientHints: [],
  });
  assertEquals(without!.body.includes("اتشاف"), false);
});


// ── الشريحة ٢٨: «أرخص هنا» ──────────────────────────────────────────────────────────

const NOW = Date.parse("2026-10-04T12:00:00Z");
const r = (item: string, store: string, price: number, daysAgo: number) => ({
  item_name: item, store_name: store, price, timestamp: new Date(NOW - daysAgo * 86_400_000).toISOString(),
});

Deno.test("cheaperHere: the latest price here against the median elsewhere", () => {
  const reports = [
    r("لبن جهينة", "كارفور ماركت", 38, 5), r("لبن", "كارفور", 35, 1), // الأحدث هنا: 35
    r("لبن", "خير زمان", 40, 3), r("لبن", "سعودي", 42, 10), r("لبن", "هايبر وان", 39, 20),
    r("عيش", "كارفور", 10, 1), r("عيش", "خير زمان", 10, 2), r("عيش", "سعودي", 10, 3), r("عيش", "هايبر وان", 10, 4),
  ];
  assertEquals(cheaperHereItems(reports, "كارفور", ["لبن", "عيش"], NOW), [{ item: "لبن", price: 35, typical: 40 }]);
});

Deno.test("cheaperHere: under three reports elsewhere is not a market price", () => {
  const reports = [r("لبن", "كارفور", 30, 1), r("لبن", "خير زمان", 40, 3), r("لبن", "سعودي", 42, 10)];
  assertEquals(cheaperHereItems(reports, "كارفور", ["لبن"], NOW), []);
});

Deno.test("cheaperHere: an old price here, or within 5%, says nothing", () => {
  const elsewhere = [r("لبن", "خير زمان", 40, 3), r("لبن", "سعودي", 40, 4), r("لبن", "هايبر وان", 40, 5)];
  assertEquals(cheaperHereItems([...elsewhere, r("لبن", "كارفور", 30, 20)], "كارفور", ["لبن"], NOW), [], "20 days old");
  assertEquals(cheaperHereItems([...elsewhere, r("لبن", "كارفور", 39, 1)], "كارفور", ["لبن"], NOW), [], "only 2.5% cheaper");
});

Deno.test("the arrival message names the cheaper price, and only when there is one", () => {
  const msg = buildStoreArrivalMessage({
    storeName: "كارفور", category: "supermarket", shopping: ["لبن"], lowStock: [], clientHints: [],
    cheaperHere: [{ item: "لبن", price: 35, typical: 40 }],
  });
  assertStringIncludes(msg!.body, "💰 أرخص هنا من فواتير عملاء زاد: لبن 35 (في محلات تانية حوالي 40)");
  const none = buildStoreArrivalMessage({
    storeName: "كارفور", category: "supermarket", shopping: ["لبن"], lowStock: [], clientHints: [],
  });
  assertEquals(none!.body.includes("أرخص"), false);
});

Deno.test("normalizeForPerson: a name as said, the customer's own words for 'me' are null", () => {
  assertEquals(normalizeForPerson(" ماما "), "ماما");
  assertEquals(normalizeForPerson("أنا"), null);
  assertEquals(normalizeForPerson(""), null);
  assertEquals(normalizeForPerson(undefined), null);
  assertEquals(normalizeForPerson("«يوسف»\n"), "يوسف");
  assertEquals(normalizeForPerson("x".repeat(80))!.length, 40);
});

Deno.test("normalizeForPerson: the same relative is one person, whatever word is used", () => {
  for (const w of ["ماما", "أمي", "امي", "والدتي", "لماما", "لـ ماما", "Mom"]) assertEquals(normalizeForPerson(w), "ماما", w);
  for (const w of ["بابا", "أبويا", "والدي", "لبابا"]) assertEquals(normalizeForPerson(w), "بابا", w);
  assertEquals(normalizeForPerson("جدتي"), "تيتا");
  assertEquals(normalizeForPerson("زوجتي"), "مراتي");
  // Names stay names, even ones starting with «ل».
  assertEquals(normalizeForPerson("لينا"), "لينا");
  assertEquals(normalizeForPerson("سارة"), "سارة");
  assertEquals(normalizeForPerson("ليا"), null);
});
