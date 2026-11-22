import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import { restockAlerts } from "./restockAlert.ts";
import { observeRestock } from "./restockAvailabilityData.ts";

const fake = (byItem: Record<string, unknown[]>) => ({
  rpc: (_fn: string, a: Record<string, unknown>) =>
    Promise.resolve({ data: byItem[a.p_item_key as string] ?? [], error: null }),
});
const near = (store: string, inStock: boolean, age = 1) => ({ store_key: store, in_stock: inStock, age_days: age, area_lat: 30.04, area_lng: 31.23 });
const home = { lat: 30.041, lng: 31.231 };

Deno.test("alert only for likely + near; text has no who/source", async () => {
  const sb = fake({
    لبن: [near("كارفور", true), near("كارفور", true, 2)],
    زيت: [near("سبينس", false)],
    رز: [{ store_key: "بعيد", in_stock: true, age_days: 1, area_lat: 31.2, area_lng: 29.9 }, { store_key: "بعيد", in_stock: true, age_days: 2, area_lat: 31.2, area_lng: 29.9 }],
    سكر: [{ store_key: "مجهول", in_stock: true, age_days: 1, area_lat: null, area_lng: null }],
  });
  const a = await restockAlerts(sb, { country: "EG", home, needed: ["لبن", "زيت", "رز", "سكر", "لبن"] });
  assertEquals(a.map((x) => x.item), ["لبن"]);
  assert(a[0].text.includes("كارفور") && !/اشترى|أبلغ|فاتورة|نشرة/.test(a[0].text));
});

Deno.test("caps at max, RPC error throws", async () => {
  const sb = fake({ أ1: [near("م", true), near("م", true)], ب1: [near("م", true), near("م", true)], ج1: [near("م", true), near("م", true)] });
  assertEquals((await restockAlerts(sb, { country: "EG", home, needed: ["أ1", "ب1", "ج1"], max: 2 })).length, 2);
  const bad = { rpc: () => Promise.resolve({ data: null, error: { message: "x" } }) };
  await assertRejects(() => restockAlerts(bad, { country: "EG", home, needed: ["لبن"] }));
});

Deno.test("observeRestock passes anonymous args, false when ignored, throws on error", async () => {
  let seen: Record<string, unknown> = {};
  const sb = { rpc: (_f: string, a: Record<string, unknown>) => { seen = a; return Promise.resolve({ data: false, error: null }); } };
  assertEquals(await observeRestock(sb, { country: "EG", store: "كارفور", item: "لبن", inStock: true, source: "flyer", area: { lat: 30.04, lng: 31.23 } }), false);
  assertEquals(Object.keys(seen).sort(), ["p_country", "p_in_stock", "p_item_key", "p_lat", "p_lng", "p_observed_at", "p_source_kind", "p_store_key"]);
  await assertRejects(() => observeRestock({ rpc: () => Promise.resolve({ data: null, error: { message: "bad_source" } }) }, { country: "EG", store: "a", item: "b", inStock: true, source: "flyer" }));
});
