import { assertEquals } from "jsr:@std/assert@1";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { dealPutPayload, findCustomerCities, searchedDeals } from "./storeDeals.ts";

const target = { country: "SA", store: "كيو", currency: "SAR" };

Deno.test("a searched offer becomes a country-wide search row with its link", () => {
  const row = dealPutPayload(target, {
    item_name: "زيت عافية ١.٥ لتر", price: 21.95, price_before: 27.5,
    valid_until: "2026-10-31T23:59:59.000Z", source_url: "https://example.com/q",
  });
  assertEquals(row.city, "");
  assertEquals(row.source_kind, "search");
  assertEquals(row.deal_kind, "discount");
  assertEquals(row.currency, "SAR");
  assertEquals(row.source_url, "https://example.com/q");
});

Deno.test("an offer with no price before is a plain price", () => {
  const row = dealPutPayload(target, {
    item_name: "رز", price: 40, price_before: null, valid_until: null, source_url: "https://example.com/r",
  });
  assertEquals(row.deal_kind, "price");
  assertEquals(row.valid_until, null);
});

Deno.test("only well-formed deals from store_deals are kept", () => {
  assertEquals(searchedDeals(null), []);
  assertEquals(searchedDeals({ deals: "x" }), []);
  const kept = searchedDeals({
    deals: [
      { item_name: "رز", price: 40, price_before: null, valid_until: null, source_url: "https://a.com" },
      { item_name: "سكر", price: "12", source_url: "https://a.com" },
      { price: 3, source_url: "https://a.com" },
    ],
  });
  assertEquals(kept.map((d) => d.item_name), ["رز"]);
});

Deno.test("a section heading is not an item (the 29/10 search, reviewed 2/11)", () => {
  const d = (item_name: string, price = 10) => ({ item_name, price, price_before: null, valid_until: null, source_url: "https://x" });
  const kept = searchedDeals({
    deals: [
      d("أجهزة", 5099), d("عروض الآيس كريم والحلويات الباردة", 5.75), d("Offers"),
      d("Saban أرز مصري رفيع الحبة ٥ كجم", 119.95), d("لبنة فاخرة كاملة الدسم-400 غرام", 8.99), d("صامولي", 0.5),
      d("عرضة فول", 0), // سعر صفر
      d("أجهزة منزلية سامسونج غسالة 7 كيلو", 9999),
    ],
  }).map((x) => x.item_name);
  assertEquals(kept, ["Saban أرز مصري رفيع الحبة ٥ كجم", "لبنة فاخرة كاملة الدسم-400 غرام", "صامولي", "أجهزة منزلية سامسونج غسالة 7 كيلو"]);
});

Deno.test("a deal read from a store's YouTube video is a youtube row with the video as its link", () => {
  const row = dealPutPayload({ country: "SA", store: "كيو", currency: "SAR" },
    { item_name: "زبادي يوناني", price: 1.8, price_before: null, valid_until: null, source_url: "https://www.youtube.com/watch?v=aaaaaaaaaa1" }, "youtube");
  assertEquals(row.source_kind, "youtube");
  assertEquals(row.source_url, "https://www.youtube.com/watch?v=aaaaaaaaaa1");
});

Deno.test("a target with a city writes its rows for that city (ZAD_PLAN 4.3)", () => {
  const deal = { item_name: "رز", price: 40, price_before: null, valid_until: null, source_url: "https://example.com/r" };
  assertEquals(dealPutPayload({ ...target, city: "الرياض" }, deal).city, "الرياض");
  assertEquals(dealPutPayload(target, deal).city, "");
});

function citySb(needing: unknown[], rpcError: string | null = null) {
  const saved: Array<Record<string, unknown>> = [];
  const sb = {
    rpc: (fn: string) => Promise.resolve(fn === "zad_users_needing_city" ? { data: needing, error: rpcError ? { message: rpcError } : null } : { data: null, error: null }),
    from: (table: string) => ({
      upsert: (row: Record<string, unknown>, opts: { onConflict: string }) => {
        saved.push({ table, onConflict: opts.onConflict, ...row });
        return Promise.resolve({ error: null });
      },
    }),
  } as unknown as SupabaseClient;
  return { sb, saved };
}

Deno.test("cities: the coarse point is asked about, the name alone is kept; failures and trips keep what was there", async () => {
  const { sb, saved } = citySb([
    { user_id: "a", country: "SA", lat: 24.71, lon: 46.68 },
    { user_id: "b", country: "SA", lat: 21.49, lon: 39.19 },
    { user_id: "c", country: "SA", lat: 25.2, lon: 55.27 },
    { user_id: "d", country: "EG", lat: 30.0, lon: 31.0 },
    { user_id: "e", country: "SA", lat: 22.0, lon: 50.0 },
  ]);
  const asked: unknown[] = [];
  const answers: Record<string, unknown> = {
    "24.71": { ok: true, city: "الرياض", other_country: false },
    "21.49": null, // core-intelligence وقع
    "25.2": { ok: true, city: "", other_country: true }, // النقطة في دبي والحساب سعودي
    "30": { ok: false, reason: "no_key" },
    "22": { ok: true, city: "", other_country: false }, // صحرا: اتسأل ومفيش مدينة
  };
  const n = await findCustomerCities(sb, (p) => {
    asked.push(p);
    return Promise.resolve(answers[String(p.lat)] as never);
  }, { pauseMs: 0, now: () => new Date("2026-11-05T03:41:00Z") });
  assertEquals(asked[0], { lat: 24.71, lon: 46.68, country: "SA" });
  assertEquals(n, 2);
  assertEquals(saved, [
    { table: "zad_user_city", onConflict: "user_id", user_id: "a", country: "SA", city: "الرياض", found_at: "2026-11-05T03:41:00.000Z" },
    { table: "zad_user_city", onConflict: "user_id", user_id: "e", country: "SA", city: "", found_at: "2026-11-05T03:41:00.000Z" },
  ]);
});

Deno.test("cities: a failed read asks nobody", async () => {
  const { sb, saved } = citySb([], "boom");
  let asked = 0;
  assertEquals(await findCustomerCities(sb, () => { asked++; return Promise.resolve(null); }, { pauseMs: 0 }), 0);
  assertEquals([asked, saved.length], [0, 0]);
});
