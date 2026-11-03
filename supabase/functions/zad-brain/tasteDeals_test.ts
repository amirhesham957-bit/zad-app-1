// العروض حسب الذوق (tasteDeals.ts، الموجة ٤): مرة في الصبح، لو طابقت ذوقه بس، ومحلاته الأول.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { askedDealKeys, dealSource, favoriteStores, loadTasteDeal, pickDeal, tasteItems } from "./tasteDeals.ts";
import { momentFallback, morningFacts } from "./voiceMoments.ts";
import { weatherSource } from "./weather.ts";

weatherSource.fetch = () => Promise.reject(new Error("no network in unit tests"));

Deno.test("taste: the open shopping list first, then interests, five at most, no repeats", () => {
  assertEquals(tasteItems(["زيت", "  رز ", "زيت"], ["قهوة", "رز", "x", "شاي", "لبن", "عيش"]), ["زيت", "رز", "قهوة", "شاي", "لبن"]);
  assertEquals(tasteItems([], []), []);
});

Deno.test("taste: a store visited three times in sixty days is a favourite; an app package is not a store", () => {
  const rows = [
    ...Array(4).fill({ merchant_name: "كارفور" }), ...Array(3).fill({ merchant_name: "خير زمان" }),
    ...Array(2).fill({ merchant_name: "سعودي" }), ...Array(5).fill({ merchant_name: "com.google.android.apps.messaging" }),
    { merchant_name: null },
  ];
  assertEquals(favoriteStores(rows), ["كارفور", "خير زمان"]);
});

const DEALS = [
  { item: "زيت عباد الشمس كريستال", store: "هايبر وان", price: 85, discount_percent: 20 },
  { item: "زيت كريستال", store: "كارفور مصر", price: 90, discount_percent: 10 },
  { item: "تليفزيون", store: "كارفور", discount_percent: 50 },
  { item: "رز", store: "", price: 30 },
  { item: "رز", store: "سعودي", price: 0, discount_percent: 0 },
];

Deno.test("deal: only one of their items, at a named store with a price or discount — their store first", () => {
  const d = pickDeal(DEALS, ["زيت", "رز"], ["كارفور"], new Set())!;
  // محله يغلب الخصم الأكبر.
  assertEquals([d.store, d.favorite, d.discount_percent, d.key], ["كارفور مصر", true, 10, "deal:زيت:كارفور مصر"]);
  // من غير محلات متكررة: أكبر خصم.
  assertEquals(pickDeal(DEALS, ["زيت"], [], new Set())?.store, "هايبر وان");
  // عرض على حاجة مش في ذوقه (تليفزيون) مايتقالش أبداً؛ ولا محل من غير اسم، ولا من غير سعر/خصم.
  assertEquals(pickDeal(DEALS, ["لبن"], ["كارفور"], new Set()), null);
  assertEquals(pickDeal(DEALS, ["رز"], [], new Set()), null);
  // اتقال الأسبوع ده ⇒ اللي بعده.
  assertEquals(pickDeal(DEALS, ["زيت"], ["كارفور"], new Set(["deal:زيت:كارفور مصر"]))?.store, "هايبر وان");
  assertEquals(pickDeal("not a list", ["زيت"], [], new Set()), null);
  assertEquals([...askedDealKeys([{ facts: { taste_deal: { key: "deal:a:b" } } }, { facts: null }])], ["deal:a:b"]);
});

Deno.test("deal, tight: the most urgent need first, a price is required, then the cheapest, then the nearer", () => {
  const deals = [
    { item: "زيت عافية", store: "كارفور", price: 70 },
    { item: "رز مصري", store: "خير زمان", discount_percent: 40 },
    { item: "رز مصري", store: "بنده", price: 30 },
    { item: "رز مصري", store: "العثيم", price: 28 },
    { item: "رز مصري", store: "الدانوب", price: 28 },
  ];
  const d = pickDeal(deals, ["رز", "زيت"], ["بنده"], new Set(), ["الدانوب"], true)!;
  assertEquals([d.store, d.price, d.nearby, d.tight], ["الدانوب", 28, true, true]);
  // خصم من غير سعر مايتقالش والفلوس ضيقة.
  assertEquals(pickDeal([deals[1]], ["رز"], [], new Set(), [], true), null);
});

Deno.test("deal: the need is matched by word — «زيت» is not «زيتون», and «لبن» finds «حليب» (ZAD_PLAN 4.6)", () => {
  const deals = [
    { item: "زيتون أسود", store: "كارفور", price: 40, discount_percent: 30 },
    { item: "حليب المراعي 1 لتر", store: "بنده", price: 6 },
  ];
  assertEquals(pickDeal(deals, ["زيت"], [], new Set()), null);
  const milk = pickDeal(deals, ["لبن"], [], new Set())!;
  assertEquals([milk.store, milk.key], ["بنده", "deal:لبن:بنده"]);
});

function fakeSb(tables: Record<string, unknown[]>, rpcs: Record<string, unknown> = {}): SupabaseClient {
  const chain = (data: unknown): unknown =>
    new Proxy({}, {
      get(_t, prop) {
        if (prop === "then") return (res: (v: unknown) => unknown) => Promise.resolve({ data, error: null }).then(res);
        if (prop === "maybeSingle" || prop === "single") return () => chain(Array.isArray(data) ? data[0] ?? null : data);
        return () => chain(data);
      },
    });
  return { from: (t: string) => chain(tables[t] ?? []), rpc: (fn: string) => chain(rpcs[fn] ?? null) } as unknown as SupabaseClient;
}

const TABLES = {
  zad_users: [{ id: "u", country: "EG", created_at: "2025-01-01T00:00:00Z" }],
  zad_shopping_list: [{ item_name: "زيت" }],
  zad_customer_profile: [{ interests: ["قهوة"] }],
  zad_transactions: Array(3).fill({ merchant_name: "كارفور" }),
};

Deno.test("deal: one search in the customer's market; in «أنا مفلس» the needs only at the lowest price; none without items", async () => {
  const asked: Array<Record<string, unknown>> = [];
  dealSource.search = (payload) => { asked.push(payload); return Promise.resolve({ deals: DEALS }); };
  const d = await loadTasteDeal(fakeSb(TABLES), "u");
  assertEquals(d?.store, "كارفور مصر");
  assertEquals(asked, [{ items: ["زيت", "قهوة"], location: "مصر", country: "EG" }]);

  const broke = await loadTasteDeal(fakeSb({ ...TABLES, zad_broke_mode: [{ ends_at: new Date(Date.now() + 86_400_000).toISOString(), ended_at: null }] }), "u");
  // ZAD_PLAN ٤.٨: «أنا مفلس» = النواقص بس، من غير الاهتمامات، وأرخص سعر — محله المعتاد مش ميزة لو أغلى.
  assertEquals([broke?.store, broke?.price, broke?.tight, asked.length], ["هايبر وان", 85, true, 2]);
  assertEquals(asked[1].items, ["زيت"]);
  assertEquals(await loadTasteDeal(fakeSb({ ...TABLES, zad_shopping_list: [], zad_customer_profile: [{ interests: [] }] }), "u"), null);
  assertEquals(asked.length, 2);
  dealSource.search = () => Promise.reject(new Error("down"));
  assertEquals(await loadTasteDeal(fakeSb(TABLES), "u"), null);
});

const LOCAL = { date: "2026-10-11", time_zone: "Africa/Cairo", utc_offset: "+03:00" };

Deno.test("morning: the deal is the greeting's last line — and while the budget is in danger, the cheapest price on a need", async () => {
  dealSource.search = () => Promise.resolve({ deals: DEALS });
  const facts = await morningFacts(fakeSb(TABLES, { zad_budget_state: { threat: "SAFE" } }), "u", LOCAL);
  assertEquals((facts.taste_deal as { store: string }).store, "كارفور مصر");
  const msg = momentFallback("morning_greeting", facts);
  assertStringIncludes(msg.text, "فيه عرض عليه في كارفور مصر (محلك) بخصم 10٪");
  for (const threat of ["DANGER", "OVER"]) {
    const tight = await morningFacts(fakeSb(TABLES, { zad_budget_state: { threat } }), "u", LOCAL);
    assertEquals((tight.taste_deal as { tight?: boolean }).tight, true, threat);
    const line = momentFallback("morning_greeting", tight).text;
    assertStringIncludes(line, "أرخص زيت عباد الشمس كريستال لقيته في هايبر وان بـ85.");
    assert(!line.includes("فيه عرض"), threat);
  }
  assert(!momentFallback("morning_greeting", {}).text.includes("عرض"));
  dealSource.search = () => Promise.resolve(null);
});

// ZAD_PLAN 3.14: abroad, the morning deal is from the country they are in.
import { dealCountry } from "./tasteDeals.ts";

Deno.test("the morning deal searches where the customer is now", () => {
  const now = Date.parse("2026-10-25T10:00:00Z");
  const since = new Date(now - 3 * 86_400_000).toISOString();
  assertEquals(dealCountry({ country: "EG", travel_country: "SA", travel_since: since }, now), "SA");
  assertEquals(dealCountry({ country: "SA", travel_country: null, travel_since: null }, now), "SA");
  assertEquals(dealCountry({ country: "sa", travel_country: "SA", travel_since: since }, now), "SA");
  assertEquals(dealCountry(null, now), "");
});

// ZAD_PLAN ٤.٨/٤.٩: zad_deals الأول — عرض متخزّن بمصدره وتاريخه يغلب البحث، ومن غير ما نبحث خالص.
import { runningOutNames, storedDeals } from "./tasteDeals.ts";

const STORED = [
  { store: "كارفور", item_name: "زيت عافية ١.٥ لتر", price: "72", price_before: "90", source_kind: "search",
    source_url: "https://example.com/carrefour", valid_until: "2026-10-30T00:00:00Z" },
  { store: "بنده", item_name: "تليفزيون", price: 900, price_before: 1800, source_kind: "search", source_url: "https://x.example", valid_until: null },
];

Deno.test("stored deals: the discount comes from the price before, and the source rides along", () => {
  const [oil, tv] = storedDeals(STORED);
  assertEquals([oil.price, oil.discount_percent], [72, 20]);
  assertEquals(oil.source, { kind: "search", url: "https://example.com/carrefour", until: "2026-10-30T00:00:00Z" });
  assertEquals(tv.discount_percent, 50);
  assertEquals(storedDeals([{ ...STORED[0], price_before: null }])[0].discount_percent, null);
  assertEquals(storedDeals(null), []);
  assertEquals(runningOutNames({ pantry: { running_out: [{ name: "رز", days: 3 }, { name: "" }] } }), ["رز"]);
  assertEquals(runningOutNames(null), []);
});

Deno.test("deal: a stored deal on what they need wins, with no search at all", async () => {
  let searched = 0;
  dealSource.search = () => { searched++; return Promise.resolve({ deals: DEALS }); };
  const d = await loadTasteDeal(fakeSb({ ...TABLES, zad_deals: STORED }), "u");
  assertEquals([d?.store, d?.discount_percent, d?.favorite, d?.source?.until, searched], ["كارفور", 20, true, "2026-10-30", 0]);

  // صنف هيخلص خلال أسبوع (حالة البيت) احتياج زي القايمة؛ العرض اللي مالوش احتياج (التليفزيون) مايتقالش.
  const rice = [{ ...STORED[0], item_name: "رز مصري ٥ كيلو", store: "خير زمان" }, STORED[1]];
  const r = await loadTasteDeal(fakeSb({
    ...TABLES, zad_shopping_list: [], zad_customer_profile: [{ interests: [] }], zad_deals: rice,
    zad_home_state: [{ state: { pantry: { running_out: [{ name: "رز", days: 2 }] } } }],
  }), "u");
  assertEquals([r?.item, searched], ["رز مصري ٥ كيلو", 0]);

  // مفيش متخزّن يطابق ⇒ البحث الحي زي الأول.
  const live = await loadTasteDeal(fakeSb({ ...TABLES, zad_deals: [STORED[1]] }), "u");
  assertEquals([live?.store, live?.source, searched], ["كارفور مصر", undefined, 1]);
  dealSource.search = () => Promise.resolve(null);
});

Deno.test("morning: a stored deal says until when — and the saving in money, not a percent (ZAD_PLAN 4.9)", async () => {
  dealSource.search = () => Promise.resolve(null);
  const facts = await morningFacts(fakeSb({ ...TABLES, zad_deals: STORED }, { zad_budget_state: { threat: "SAFE" } }), "u", LOCAL);
  const deal = facts.taste_deal as { price_before?: number; saving?: number };
  assertEquals([deal.price_before, deal.saving], [90, 18]);
  assertStringIncludes(momentFallback("morning_greeting", facts).text, "فيه عرض عليه في كارفور (محلك) بـ72 بدل 90 (توفّر 18) لحد 2026-10-30.");

  // من غير سعر قبل (البحث الحي، أو «قبل» مش أغلى) مفيش توفير يتقال — النسبة زي ما هي.
  const flat = await morningFacts(fakeSb({ ...TABLES, zad_deals: [{ ...STORED[0], price_before: "72" }] }, { zad_budget_state: { threat: "SAFE" } }), "u", LOCAL);
  assertEquals((flat.taste_deal as { saving?: number }).saving, undefined);
});

// ZAD_PLAN ٤.٧: المحلات حوالين آخر نقطة ليه — بعد محلاته المتكررة وقبل الخصم الأكبر.
import { nearbyPoint, nearbySource, nearbyStoreNames } from "./tasteDeals.ts";

Deno.test("nearby: a fresh point is rounded to about a kilometre; an old or missing one is no point", () => {
  const now = Date.parse("2026-10-26T10:00:00Z");
  const fresh = new Date(now - 2 * 86_400_000).toISOString();
  assertEquals(nearbyPoint({ last_lat: 24.71362, last_lon: 46.67531, last_location_at: fresh }, now), { lat: 24.71, lon: 46.68 });
  assertEquals(nearbyPoint({ last_lat: 24.7, last_lon: 46.6, last_location_at: new Date(now - 8 * 86_400_000).toISOString() }, now), null);
  assertEquals(nearbyPoint({ last_lat: null, last_lon: 46.6, last_location_at: fresh }, now), null);
  assertEquals(nearbyPoint(null, now), null);
  assertEquals(nearbyStoreNames({ stores: [{ name: "بنده - النخيل" }, { name: "" }, {}] }), ["بنده - النخيل"]);
  assertEquals(nearbyStoreNames(null), []);
});

Deno.test("nearby: their own store first, then the one near them, then the bigger discount", () => {
  const deals = [
    { item: "زيت عافية", store: "كارفور", price: 70, discount_percent: 30 },
    { item: "زيت عافية", store: "بنده", price: 80, discount_percent: 10 },
    { item: "زيت عافية", store: "العثيم", price: 75, discount_percent: 20 },
  ];
  assertEquals(pickDeal(deals, ["زيت"], [], new Set(), ["بنده - النخيل"])?.store, "بنده");
  assertEquals(pickDeal(deals, ["زيت"], [], new Set(), ["بنده - النخيل"])?.nearby, true);
  assertEquals(pickDeal(deals, ["زيت"], ["العثيم"], new Set(), ["بنده - النخيل"])?.store, "العثيم");
  assertEquals(pickDeal(deals, ["زيت"], [], new Set())?.store, "كارفور");
});

Deno.test("nearby: the morning asks around their coarse point, and says «قريب منك»", async () => {
  const at = new Date(Date.now() - 86_400_000).toISOString();
  let asked: Record<string, unknown> | null = null;
  nearbySource.search = (payload) => { asked = payload; return Promise.resolve({ stores: [{ name: "خير زمان فرع المعادي" }] }); };
  dealSource.search = () => Promise.resolve(null);
  const deals = [
    { ...STORED[0], store: "هايبر وان", price_before: "100" },
    { ...STORED[0], store: "خير زمان", price_before: "80" },
  ];
  const users = [{ id: "u", country: "EG", created_at: "2025-01-01T00:00:00Z", last_lat: 29.96051, last_lon: 31.25712, last_location_at: at }];
  const d = await loadTasteDeal(fakeSb({ ...TABLES, zad_users: users, zad_transactions: [], zad_deals: deals }), "u");
  assertEquals([d?.store, d?.nearby], ["خير زمان", true]);
  assertEquals(asked, { lat: 29.96, lon: 31.26, tag: "supermarket", radius_meters: 3000 });
  assertStringIncludes(momentFallback("morning_greeting", { taste_deal: d }).text, "خير زمان (قريب منك)");

  // البحث عن المحلات وقع ⇒ العرض برضه، من غير ترتيب بالقرب.
  nearbySource.search = () => Promise.reject(new Error("down"));
  const fallback = await loadTasteDeal(fakeSb({ ...TABLES, zad_users: users, zad_transactions: [], zad_deals: deals }), "u");
  assertEquals([fallback?.store, fallback?.nearby], ["هايبر وان", false]);
  nearbySource.search = () => Promise.resolve(null);
});

// ZAD_PLAN ٤.١٥: ماركة البيت من المشتريات — أسامي من مخزن حقيقي (٢٦/١٠).
import { houseBrands, offerBrand } from "./tasteDeals.ts";

const BOUGHT = [
  "شاي اسود 40جم بروك", "شاي اسود 40 جم بروك",
  "ماء إيلان", "ماء إيلان", "مياه نستله بيور لايف", "ماء بوفانا", "مياه داساني جالون",
  "صافي مياه معدنية 1.5 لتر", "صافي, مياه معدنيه 1.5 لتر", "ماء صافى",
  "اريا لبن كامل الدسم 1 لتر", "حليب", "خميرة فورى 12 جم دريم", "فانيليا 2 جم دريم",
];

Deno.test("house brand: twice and at least half of that staple's buys; descriptors and sizes are not brands", () => {
  const brands = houseBrands(BOUGHT);
  // الشاي: بروك مرتين من مرتين. المية: صافي ٣ من ٨ — مش نص، فمفيش ماركة. اللبن: «كامل» و«دسم» أوصاف.
  assertEquals([...brands.values()], ["بروك"]);
  assertEquals(offerBrand("شاي بروك 100 جم", brands), "بروك");
  assertEquals(offerBrand("شاي العروسة 40 فتلة", brands), null);
  // «دريم» اتكرر بس مع حاجات مش من الأساسيات — مالوش صنف يتربط بيه.
  assertEquals(offerBrand("خميرة دريم", brands), null);
  assertEquals(houseBrands([]).size, 0);
});

Deno.test("house brand: an offer on their brand comes after their store and before a nearer one or a bigger discount", () => {
  const brands = houseBrands(BOUGHT);
  const deals = [
    { item: "شاي العروسة", store: "بنده", price: 20, discount_percent: 40 },
    { item: "شاي بروك 40 جم", store: "العثيم", price: 22, discount_percent: 10 },
  ];
  const d = pickDeal(deals, ["شاي"], [], new Set(), ["بنده"], false, brands)!;
  assertEquals([d.store, d.brand], ["العثيم", "بروك"]);
  assertStringIncludes(momentFallback("morning_greeting", { taste_deal: d }).text, "(الماركة اللي بتجيبوها)");
  // محله المعتاد لسه الأول.
  assertEquals(pickDeal(deals, ["شاي"], ["بنده"], new Set(), [], false, brands)?.store, "بنده");
  // والفلوس ضيقة: الأرخص، مش الماركة.
  assertEquals(pickDeal(deals, ["شاي"], [], new Set(), [], true, brands)?.store, "بنده");
});

// ZAD_PLAN ٤.٢٠: «مش مهتم» بيسكّت الاحتياج ده ٣٠ يوم في أي محل؛ والعرض اللي اتقال بيتكرر بعد أسبوع زي الأول.
import { hasDealButtons } from "./voiceMoments.ts";

Deno.test("declined: «not interested» quiets that need for 30 days at any store; a plain repeat waits a week", () => {
  const now = Date.parse("2026-10-26T08:00:00Z");
  const day = 86_400_000;
  const keys = askedDealKeys([
    { facts: { taste_deal: { key: "deal:زيت:كارفور", answer: "no" } }, created_at: new Date(now - 20 * day).toISOString() },
    { facts: { taste_deal: { key: "deal:رز:بنده" } }, created_at: new Date(now - 10 * day).toISOString() },
    { facts: { taste_deal: { key: "deal:شاي:كيو" } }, created_at: new Date(now - 2 * day).toISOString() },
  ], now);
  assertEquals([...keys].sort(), ["deal:شاي:كيو", "need:زيت"]);
  const deals = [{ item: "زيت عافية", store: "بنده", price: 60 }, { item: "رز مصري", store: "بنده", price: 30 }];
  assertEquals(pickDeal(deals, ["زيت", "رز"], [], keys)?.item, "رز مصري");
});

Deno.test("reported wrong (4.19): the same deal stays quiet for 30 days, the need does not", () => {
  const now = Date.parse("2026-11-03T08:00:00Z");
  const keys = askedDealKeys([
    { facts: { taste_deal: { key: "deal:زيت:كيو", answer: "wrong" } }, created_at: new Date(now - 20 * 86_400_000).toISOString() },
  ], now);
  assertEquals([...keys], ["deal:زيت:كيو"]);
});

Deno.test("deal buttons ride only on a morning greeting that carries a deal", () => {
  assert(hasDealButtons("morning_greeting", { taste_deal: { item: "زيت" } }));
  assert(!hasDealButtons("morning_greeting", { weather: {} }));
  assert(!hasDealButtons("good_night", { taste_deal: { item: "زيت" } }));
});

// ZAD_PLAN ٤.٨: الميزانية مرتاحة ⇒ عرض على أساسي بيتخزّن والبيت بيشتريه = فرصة تخزين.
import { storableBought } from "./tasteDeals.ts";
import { budgetComfortable } from "./householdLoad.ts";

Deno.test("comfortable: SAFE with 30% of the budget left; anything else is not", () => {
  assertEquals(budgetComfortable("SAFE", 300, 1000), true);
  assertEquals(budgetComfortable("SAFE", 299, 1000), false);
  assertEquals(budgetComfortable("WATCH", 900, 1000), false);
  assertEquals(budgetComfortable("SAFE", 900, null), false);
  assertEquals(budgetComfortable("SAFE", null, 1000), false);
});

Deno.test("stock up: only staples that keep, and only ones the house has bought", () => {
  const groups = storableBought(["زيت كريستال ١ لتر", "لبن جهينة", "عيش بلدي", "رز الضحى ٥ كيلو"]);
  assertEquals(pickDeal([{ item: "زيت عافية", store: "كارفور", price: 72, discount_percent: 20 }], ["زيت"], [], new Set(), [], false, new Map(), groups)?.stock, true);
  assertEquals(pickDeal([{ item: "لبن المراعي", store: "كارفور", price: 30, discount_percent: 20 }], ["لبن"], [], new Set(), [], false, new Map(), groups)?.stock, undefined);
  assertEquals(pickDeal([{ item: "سكر الأسرة", store: "كارفور", price: 30, discount_percent: 20 }], ["سكر"], [], new Set(), [], false, new Map(), groups)?.stock, undefined);
  // سعر من غير خصم مش فرصة.
  assertEquals(pickDeal([{ item: "زيت عافية", store: "كارفور", price: 72 }], ["زيت"], [], new Set(), [], false, new Map(), groups)?.stock, undefined);
});

Deno.test("morning: a comfortable, confirmed budget turns a staple's deal into a chance to stock up", async () => {
  dealSource.search = () => Promise.resolve(null);
  const tables = { ...TABLES, zad_deals: STORED, zad_inventory: [{ item_name: "زيت عافية ١.٥ لتر" }] };
  const easy = { threat: "SAFE", limit_confirmed: true, monthly_limit: 10000, available: 4000 };
  const facts = await morningFacts(fakeSb(tables, { zad_budget_state: easy }), "u", LOCAL);
  assertEquals((facts.taste_deal as { stock?: boolean }).stock, true);
  assertStringIncludes(momentFallback("morning_greeting", facts).text, "لحد 2026-10-30، والميزانية مرتاحة فممكن تخزّن منه.");

  for (const budget of [
    { ...easy, available: 2000 }, // أقل من ٣٠٪
    { ...easy, limit_confirmed: false }, // ميزانية مش مؤكدة
    { ...easy, threat: "DANGER" }, // ضيقة ⇒ أرخص سعر مش تخزين
  ]) {
    const f = await morningFacts(fakeSb(tables, { zad_budget_state: budget }), "u", LOCAL);
    assert(f.taste_deal, JSON.stringify(budget));
    assertEquals((f.taste_deal as { stock?: boolean } | undefined)?.stock, undefined, JSON.stringify(budget));
    assert(!momentFallback("morning_greeting", f).text.includes("تخزّن"), JSON.stringify(budget));
  }
});

Deno.test("house brand: the brand they said in chat beats the one counted from purchases (4.15)", async () => {
  const { statedBrands } = await import("./tasteDeals.ts");
  const said = statedBrands(["حليب نادك", "شاي العروسة مش بروك", "بيجيبوا من كارفور"]);
  assertEquals([...said.values()].sort(), ["عروسه", "نادك"]);
  // «مش المراعي» رفض مش ماركة.
  assertEquals(statedBrands(["حليب مش المراعي"]).size, 0);
  const brands = new Map([...houseBrands(BOUGHT), ...said]);
  assertEquals(offerBrand("شاي العروسة 40 فتلة", brands), "عروسه");
  assertEquals(offerBrand("شاي بروك 100 جم", brands), null);
  assertEquals(offerBrand("نادك حليب كامل الدسم 1 لتر", brands), "نادك");
});

// ZAD_PLAN ٤.٨: «العرض الناري».
import { isFireDeal, pickFireDeal } from "./tasteDeals.ts";

Deno.test("fire deal: 40% off or 1+1 on something the house bought — never when money is tight", () => {
  const raw = storedDeals([
    { store: "كيو", item_name: "زيت عافية 1.5 لتر", price: 15, price_before: 30, source_kind: "search", source_url: "https://q.example", valid_until: null },
    { store: "كيو", item_name: "شاي ليبتون", price: 20, price_before: 25, source_kind: "search", source_url: "https://q.example", valid_until: null },
    { store: "بنده", item_name: "مكرونة", price: 10, price_before: null, source_kind: "instagram", source_url: "https://www.instagram.com/p/x/", valid_until: null, deal_kind: "multi_buy" },
    { store: "بنده", item_name: "شوكولاتة", price: 5, price_before: 20, source_kind: "search", source_url: "https://b.example", valid_until: null },
  ]);
  assert(isFireDeal(raw[0]) && !isFireDeal(raw[1]) && isFireDeal(raw[2]));
  const bought = ["زيت عافيه", "شاي", "مكرونه"];
  const fire = pickFireDeal(raw, bought, [], new Set());
  assertEquals(fire?.fire, true);
  assertEquals(fire?.item, "زيت عافية 1.5 لتر");
  assertEquals(pickFireDeal(raw, bought, [], new Set(), [], true), null);
  // the chocolate is 75% off but never bought: not a fire deal for this house.
  assertEquals(pickFireDeal(raw, ["شوكولاته"].slice(1), [], new Set()), null);
  // 1+1 rides when the oil was already said this week.
  const multi = pickFireDeal(raw, bought, [], new Set(["deal:زيت عافيه:كيو"]));
  assertEquals([multi?.item, multi?.multi_buy], ["مكرونة", true]);
  // a «not interested» on the need quiets the fire deal too.
  assertEquals(pickFireDeal(raw, ["مكرونه"], [], new Set(["need:مكرونه"])), null);
});

// قرار المالك ٣/١١: العروض توصل لوحدها — بيت من غير احتياج معروف، وبوابة الدقة أوتوماتيك.
import { EVERYDAY_STAPLES, pickStapleDeal, withoutPausedSources } from "./tasteDeals.ts";

Deno.test("staple deal: a home with no known need gets a stored deal on an everyday staple — never when money is tight", () => {
  const raw = storedDeals([
    { store: "كيو", item_name: "شاحن موبايل", price: 30, price_before: 60, source_kind: "search", source_url: "https://q.example", valid_until: null },
    { store: "بنده", item_name: "زيت عافية 1.5 لتر", price: 22, price_before: 29, source_kind: "search", source_url: "https://b.example", valid_until: null },
  ]);
  const deal = pickStapleDeal(raw, [], new Set());
  assertEquals([deal?.item, deal?.staple], ["زيت عافية 1.5 لتر", true]);
  assertEquals(pickStapleDeal(raw, [], new Set(), [], true), null);
  assertEquals(pickStapleDeal(raw, [], new Set(["deal:زيت:بنده"])), null);
  assert(EVERYDAY_STAPLES.includes("رز") && !EVERYDAY_STAPLES.includes("شاحن"));
});

Deno.test("paused sources: rows from a source the customers keep calling wrong are left out", () => {
  const rows = [{ source_kind: "search", n: 1 }, { source_kind: "youtube", n: 2 }, { source_kind: "receipt", n: 3 }];
  assertEquals(withoutPausedSources(rows, new Set(["youtube"])).map((r) => r.n), [1, 3]);
  assertEquals(withoutPausedSources(null, new Set()), []);
});

// ٤.٨: العرض الناري بيعدّي بالفئة كمان — البيت بيشتري جبنة، فـ١+١ على نوع جبنة تاني يتقال.
import { boughtFamilies } from "./tasteDeals.ts";

Deno.test("fire deal: rides on the category the house buys, not only the exact item", () => {
  assertEquals(boughtFamilies(["جبنة بيضا دومتي", "زيت عافيه", "شوكولاته", "جبنه رومي"]), ["جبنه", "زيت"]);
  const raw = storedDeals([
    { store: "كيو", item_name: "جبنة رومي", price: 40, price_before: null, source_kind: "search", source_url: "https://q.example", valid_until: null, deal_kind: "multi_buy" },
    { store: "كيو", item_name: "زبادي", price: 5, price_before: 20, source_kind: "search", source_url: "https://q.example", valid_until: null },
  ]);
  const fire = pickFireDeal(raw, ["جبنة بيضا دومتي"], [], new Set());
  assertEquals([fire?.item, fire?.fire], ["جبنة رومي", true]);
  // a house that only buys cheese is not offered yoghurt, however big the discount.
  assertEquals(pickFireDeal(raw.slice(1), ["جبنة بيضا دومتي"], [], new Set()), null);
  // never when money is tight.
  assertEquals(pickFireDeal(raw, ["جبنة بيضا دومتي"], [], new Set(), [], true), null);
});

// ٤.١٥: المحل اللي قاله في الشات بيتعدّ من محلاته.
import { statedStores } from "./tasteDeals.ts";

Deno.test("stated stores: the shop the customer named counts as theirs; a rejected one does not", () => {
  assertEquals(statedStores(["كيو", "من بنده مش العثيم", "كيو", "مش كارفور", ""]), ["كيو", "بنده"]);
  const raw = storedDeals([
    { store: "العثيم", item_name: "زيت عافية", price: 20, price_before: 30, source_kind: "search", source_url: "https://a.example", valid_until: null },
    { store: "كيو", item_name: "زيت عافية", price: 25, price_before: 30, source_kind: "search", source_url: "https://q.example", valid_until: null },
  ]);
  assertEquals(pickDeal(raw, ["زيت"], statedStores(["كيو"]), new Set())?.store, "كيو");
});

// ٤.٧ + ٤.١٠: فرع عرض البحث من المحلات حوالين نقطته، و«معندناش عربية».
import { nearbyStorePlaces, saysNoCar, withBranch } from "./tasteDeals.ts";

Deno.test("branch: a deal with no coordinates takes the nearest branch of that shop around the customer", () => {
  const places = nearbyStorePlaces({ stores: [
    { name: "كيو ماركت - العليا", lat: 24.70, lon: 46.68 },
    { name: "كيو ماركت - النخيل", lat: 24.75, lon: 46.62 },
    { name: "بنده", lat: 24.71, lon: 46.69 },
    { name: "x" },
  ] });
  assertEquals(places.length, 3);
  const home = { lat: 24.69, lon: 46.68 };
  const row = { store: "كيو ماركت", lat: null, lng: null };
  assertEquals([withBranch(row, places, home).lat, withBranch(row, places, home).lng], [24.70, 46.68]);
  // a receipt deal keeps its own point; no point or no matching shop = unchanged.
  assertEquals(withBranch({ store: "كيو ماركت", lat: 1, lng: 2 }, places, home).lat, 1);
  assertEquals(withBranch(row, places, null).lat, null);
  assertEquals(withBranch({ store: "العثيم", lat: null, lng: null }, places, home).lat, null);
});

Deno.test("transport: «معندناش عربية» or getting around by bus means no car trip; having a car does not", () => {
  for (const n of ["معندناش عربية", "مش عندنا عربية", "ماعندناش سيارة", "بنروح مواصلات", "بنطلب أوبر"]) assert(saysNoCar([n]), n);
  for (const n of ["عندنا عربية", "عندنا سيارة وبنروح مشي ساعات", ""]) assert(!saysNoCar([n]), n);
  assert(!saysNoCar([]));
});
