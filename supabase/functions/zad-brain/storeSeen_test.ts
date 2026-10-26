import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { buildStoreArrivalMessage, cheaperHereItems, normalizeForPerson, sameCity, sameStore, seenHereItems, storeKey } from "./shared.ts";

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
// Each report's reporter is its store's own shopper unless given: different stores, different homes.
const r = (item: string, store: string, price: number, daysAgo: number, user: string = `u:${store}`) => ({
  item_name: item, store_name: store, price, timestamp: new Date(NOW - daysAgo * 86_400_000).toISOString(), user_id: user,
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

Deno.test("cheaperHere: three reports from one family are one home, not a market price", () => {
  const reports = [
    r("لبن", "كارفور", 30, 1),
    r("لبن", "خير زمان", 40, 3, "mom"), r("لبن", "سعودي", 42, 4, "dad"), r("لبن", "هايبر وان", 41, 5, "son"),
  ];
  const family = new Map([["mom", "f:1"], ["dad", "f:1"], ["son", "f:1"]]);
  assertEquals(cheaperHereItems(reports, "كارفور", ["لبن"], NOW, family), []);
  assertEquals(cheaperHereItems(reports, "كارفور", ["لبن"], NOW).length, 1, "three separate homes do count");
});

Deno.test("cheaperHere: a carton typed as one pack does not move the market price", () => {
  const reports = [
    r("لبن", "كارفور", 35, 1),
    r("لبن", "خير زمان", 40, 3), r("لبن", "سعودي", 42, 4), r("لبن", "هايبر وان", 39, 5), r("لبن", "بنده", 400, 2),
  ];
  assertEquals(cheaperHereItems(reports, "كارفور", ["لبن"], NOW), [{ item: "لبن", price: 35, typical: 40 }]);
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

Deno.test("another city's report is not «here»; an unknown city still counts", () => {
  assertEquals(sameCity("الإسكندرية", "اسكندرية"), true);
  assertEquals(sameCity("القاهرة", "جدة"), false);
  assertEquals(sameCity(null, "جدة"), true);
  const now = Date.parse("2026-09-29T12:00:00Z");
  const reports = [
    { item_name: "لبن", store_name: "كارفور", timestamp: "2026-09-29T09:00:00Z", location: "جدة" },
    { item_name: "عيش", store_name: "كارفور", timestamp: "2026-09-29T10:00:00Z", location: null },
  ];
  assertEquals(seenHereItems(reports, "كارفور", ["لبن", "عيش"], now, 72, "القاهرة"), [{ item: "عيش", hours: 2 }]);
  const priced = [
    r("لبن", "كارفور", 30, 1),
    { ...r("لبن", "خير زمان", 40, 3), location: "جدة" }, r("لبن", "سعودي", 42, 4), r("لبن", "هايبر وان", 41, 5),
  ];
  assertEquals(cheaperHereItems(priced, "كارفور", ["لبن"], NOW, new Map(), "القاهرة"), [], "two homes left in the city");
  assertEquals(cheaperHereItems(priced, "كارفور", ["لبن"], NOW).length, 1);
});

// ZAD_PLAN ٤.٩: «انت جنب المحل» بيذكر العرض الساري هناك على اللي ناقص.
import { dealsHere } from "./tasteDeals.ts";

const DEAL_ROWS = [
  { store: "كارفور ماركت", item_name: "زيت عافية ١.٥ لتر", price: "72", price_before: "90", source_kind: "search", source_url: "https://x.example", valid_until: "2026-10-30T00:00:00Z" },
  { store: "كارفور", item_name: "زيت كريستال", price: 70, price_before: null, source_kind: "flyer", source_url: "https://y.example", valid_until: null },
  { store: "كارفور", item_name: "زيتون أسود", price: 30, price_before: 40, source_kind: "search", source_url: "https://z.example", valid_until: null },
  { store: "بنده", item_name: "رز الضحى", price: 40, price_before: 50, source_kind: "search", source_url: "https://w.example", valid_until: null },
  { store: "كارفور", item_name: "لبن جهينة", price: 30, price_before: "30", source_kind: "receipt", source_url: null, valid_until: null },
];

Deno.test("dealsHere: this store only, one offer per need, «زيت» is not «زيتون», «before» only when higher", () => {
  assertEquals(dealsHere(DEAL_ROWS, "كارفور", ["زيت", "رز", "لبن"]), [
    { item: "زيت عافية ١.٥ لتر", price: 72, price_before: 90, until: "2026-10-30", source_kind: "search" },
    { item: "لبن جهينة", price: 30, price_before: null, until: null, source_kind: "receipt" },
  ]);
  assertEquals(dealsHere(DEAL_ROWS, "خير زمان", ["زيت"]), []);
  assertEquals(dealsHere(null, "كارفور", ["زيت"]), []);
});

Deno.test("arrival: the deal here is named with its price, source and «ممكن يكون خلص»", () => {
  const msg = buildStoreArrivalMessage({
    storeName: "كارفور", category: "supermarket", shopping: ["زيت"], lowStock: [], clientHints: [],
    dealsHere: dealsHere(DEAL_ROWS, "كارفور", ["زيت"]),
  });
  assertStringIncludes(msg!.body, "🏷️ عليه عرض هنا: زيت عافية ١.٥ لتر بـ72 بدل 90 لحد 2026-10-30 (صفحة المحل) — ممكن يكون خلص");
  const none = buildStoreArrivalMessage({ storeName: "كارفور", category: "supermarket", shopping: ["زيت"], lowStock: [], clientHints: [] });
  assertEquals(none!.body.includes("عرض"), false);
});
