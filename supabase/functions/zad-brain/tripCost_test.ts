// المشوار ولا التوصيل (tripCost.ts، ZAD_PLAN ٤.١٠): بنزين المشوار رايح جاي، والعرض اللي المشوار بياكل توفيره مايتقالش.
import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { haversineKm, tripCost, tripEatsSaving, usableFuel } from "./tripCost.ts";
import { dealSource, loadTasteDeal, storedDeals } from "./tasteDeals.ts";
import { momentFallback } from "./voiceMoments.ts";

const NOW = Date.parse("2026-10-27T12:00:00Z");
const FUEL = { price: 19, currency: "EGP", found_at: "2026-10-02T04:23:00Z" };
const HOME = { lat: 30.05, lon: 31.23 };

Deno.test("trip: straight line × 1.3 there and back, 8 litres per 100 km, at this month's price", () => {
  // ٠٫١ درجة عرض ≈ ١١٫١ كم.
  assertEquals(Math.round(haversineKm(HOME, { lat: 30.15, lon: 31.23 }) * 10) / 10, 11.1);
  const t = tripCost(HOME, { lat: 30.15, lng: 31.23 }, FUEL)!;
  assertEquals(t, { km: 28.9, cost: 43.9 });
  // من غير إحداثيات، أو بعيد أكتر من ٣٠ كم، أو مفيش سعر = مفيش مشوار يتقال.
  assertEquals(tripCost(HOME, { lat: null, lng: null }, FUEL), null);
  assertEquals(tripCost(HOME, { lat: 31.2, lng: 29.9 }, FUEL), null);
  assertEquals(tripCost(null, { lat: 30.1, lng: 31.2 }, FUEL), null);
  assertEquals(tripCost(HOME, { lat: 30.1, lng: 31.2 }, null), null);
});

Deno.test("trip: the fuel price only when recent and in the deal's currency", () => {
  assertEquals(usableFuel(FUEL, "EGP", NOW)?.price, 19);
  assertEquals(usableFuel(FUEL, "SAR", NOW), null);
  assertEquals(usableFuel({ ...FUEL, found_at: "2026-08-01T00:00:00Z" }, "EGP", NOW), null);
  assertEquals(usableFuel(null, "EGP", NOW), null);
  assertEquals(usableFuel({ ...FUEL, price: 0 }, "EGP", NOW), null);
});

Deno.test("trip: eats the saving only when a saving is known and the fuel costs as much", () => {
  assertEquals(tripEatsSaving({ km: 20, cost: 30 }, 25), true);
  assertEquals(tripEatsSaving({ km: 20, cost: 30 }, 40), false);
  assertEquals(tripEatsSaving({ km: 20, cost: 30 }, null), false);
  assertEquals(tripEatsSaving(null, 5), false);
});

const ROWS = [
  { store: "كارفور المعادي", item_name: "زيت كريستال", price: 80, price_before: 100, currency: "EGP", source_kind: "receipt", source_url: null, valid_until: null, lat: 30.08, lng: 31.23 },
  { store: "خير زمان", item_name: "زيت عافية", price: 70, price_before: 75, currency: "EGP", source_kind: "receipt", source_url: null, valid_until: null, lat: 30.15, lng: 31.23 },
  { store: "أولاد رجب", item_name: "زيت كريستال", price: 85, price_before: 90, currency: "EGP", source_kind: "search", source_url: "https://x.example", valid_until: null, lat: null, lng: null },
];

Deno.test("trip: a deal whose trip eats its saving is dropped; the rest carry their trip", () => {
  const out = storedDeals(ROWS, (r) => tripCost(HOME, r, FUEL));
  // كارفور: توفير ٢٠ والمشوار ١٣٫٢ ⇒ يتقال. خير زمان: توفير ٥ والمشوار ٤٤ ⇒ بره. أولاد رجب من غير إحداثيات ⇒ من غير مشوار.
  assertEquals(out.map((d) => [d.store, (d.trip as { cost: number } | undefined)?.cost ?? null]), [["كارفور المعادي", 13.2], ["أولاد رجب", null]]);
  // نفس كارفور بس بعيد (المشوار ٤٤) ⇒ مايتقالش.
  assertEquals(storedDeals([{ ...ROWS[0], lat: 30.15 }], (r) => tripCost(HOME, r, FUEL)), []);
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
  return { from: (t: string) => chain(tables[t] ?? []), rpc: (name: string) => chain(rpcs[name] ?? null) } as unknown as SupabaseClient;
}

Deno.test("trip: the morning deal says the trip and the net saving", async () => {
  dealSource.search = () => Promise.resolve(null);
  const d = await loadTasteDeal(fakeSb({
    zad_users: [{ id: "u", country: "EG", last_lat: 30.05, last_lon: 31.23, last_location_at: new Date().toISOString() }],
    zad_shopping_list: [{ item_name: "زيت" }],
    zad_customer_profile: [{ interests: [] }],
    zad_deals: ROWS.slice(0, 1),
    zad_fuel_prices: [{ ...FUEL, found_at: new Date().toISOString() }],
  }), "u");
  assertEquals([d?.store, d?.trip], ["كارفور المعادي", { km: 8.7, cost: 13.2 }]);
  const line = momentFallback("morning_greeting", { taste_deal: d }).text;
  assertStringIncludes(line, "بـ80 بدل 100 (توفّر 20)، والمشوار بالعربية حوالي 8.7 كم رايح جاي بـ13.2 بنزين (يعني توفّر حوالي 6.8 صافي).");
});

// ٤.١٠: عرض في تطبيق توصيل — رسومه المعتادة من فواتير العملاء بتتطرح من التوفير، ومفيش مشوار.
import { deliveryOf } from "./tasteDeals.ts";

const FEES = [{ app_key: "ninja", app: "نينجا", fee: 9, currency: "SAR", readings: 3, homes: 2 }];
const APP_DEAL = {
  store: "Ninja", item_name: "زيت عافية", price: 20, price_before: 35, currency: "SAR", source_kind: "search",
  source_url: "https://example.com/n", valid_until: null, lat: 24.7, lng: 46.7,
};

Deno.test("delivery: an app's usual fee comes off the saving, and a fee that eats it hides the deal", () => {
  assertEquals(deliveryOf(FEES, "نينجا", "SAR"), { app: "نينجا", fee: 9 });
  assertEquals(deliveryOf(FEES, "Ninja", "EGP"), null); // عملة تانية
  assertEquals(deliveryOf(FEES, "كارفور", "SAR"), null); // مش تطبيق
  assertEquals(deliveryOf(null, "Ninja", "SAR"), null);
  const trip = () => ({ km: 5, cost: 4 });
  const [kept] = storedDeals([APP_DEAL], trip, (r) => deliveryOf(FEES, r.store, "SAR"));
  assertEquals([kept.delivery, kept.trip], [{ app: "نينجا", fee: 9 }, undefined]); // التطبيق بيوصل: مفيش مشوار
  // توفير ٥ ورسوم ٩: العرض مايتقالش.
  assertEquals(storedDeals([{ ...APP_DEAL, price: 30 }], trip, (r) => deliveryOf(FEES, r.store, "SAR")), []);
});

Deno.test("delivery: the morning deal says the app's usual fee and the net saving", async () => {
  dealSource.search = () => Promise.resolve(null);
  const d = await loadTasteDeal(fakeSb({
    zad_users: [{ id: "u", country: "SA" }],
    zad_shopping_list: [{ item_name: "زيت" }],
    zad_customer_profile: [{ interests: [] }],
    zad_deals: [APP_DEAL],
  }, { zad_delivery_fees_typical: FEES }), "u");
  assertEquals([d?.store, d?.delivery, d?.trip], ["Ninja", { app: "نينجا", fee: 9 }, undefined]);
  const line = momentFallback("morning_greeting", { taste_deal: d }).text;
  assertStringIncludes(line, "بـ20 بدل 35 (توفّر 15)، وتوصيل نينجا عادةً حوالي 9 (يعني توفّر حوالي 6 صافي).");
});
