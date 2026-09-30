import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { buildStoreArrivalMessage, normalizeForPerson, sameStore, seenHereItems, storeKey } from "./shared.ts";

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
