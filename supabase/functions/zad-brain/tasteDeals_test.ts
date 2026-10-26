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

Deno.test("deal: one search in the customer's market; none in «أنا مفلس», none without items", async () => {
  const asked: Array<Record<string, unknown>> = [];
  dealSource.search = (payload) => { asked.push(payload); return Promise.resolve({ deals: DEALS }); };
  const d = await loadTasteDeal(fakeSb(TABLES), "u");
  assertEquals(d?.store, "كارفور مصر");
  assertEquals(asked, [{ items: ["زيت", "قهوة"], location: "مصر", country: "EG" }]);

  const broke = await loadTasteDeal(fakeSb({ ...TABLES, zad_broke_mode: [{ ends_at: new Date(Date.now() + 86_400_000).toISOString(), ended_at: null }] }), "u");
  assertEquals([broke, asked.length], [null, 1]);
  assertEquals(await loadTasteDeal(fakeSb({ ...TABLES, zad_shopping_list: [], zad_customer_profile: [{ interests: [] }] }), "u"), null);
  assertEquals(asked.length, 1);
  dealSource.search = () => Promise.reject(new Error("down"));
  assertEquals(await loadTasteDeal(fakeSb(TABLES), "u"), null);
});

const LOCAL = { date: "2026-10-11", time_zone: "Africa/Cairo", utc_offset: "+03:00" };

Deno.test("morning: the deal is the greeting's last line — and not while the budget is in danger", async () => {
  dealSource.search = () => Promise.resolve({ deals: DEALS });
  const facts = await morningFacts(fakeSb(TABLES, { zad_budget_state: { threat: "SAFE" } }), "u", LOCAL);
  assertEquals((facts.taste_deal as { store: string }).store, "كارفور مصر");
  const msg = momentFallback("morning_greeting", facts);
  assertStringIncludes(msg.text, "فيه عرض عليه في كارفور مصر (محلك) بخصم 10٪");
  for (const threat of ["DANGER", "OVER"]) {
    const tight = await morningFacts(fakeSb(TABLES, { zad_budget_state: { threat } }), "u", LOCAL);
    assertEquals(tight.taste_deal, undefined, threat);
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

Deno.test("morning: a stored deal says until when", async () => {
  dealSource.search = () => Promise.resolve(null);
  const facts = await morningFacts(fakeSb({ ...TABLES, zad_deals: STORED }, { zad_budget_state: { threat: "SAFE" } }), "u", LOCAL);
  assertStringIncludes(momentFallback("morning_greeting", facts).text, "فيه عرض عليه في كارفور (محلك) بخصم 20٪ لحد 2026-10-30.");
});
