import { assert, assertAlmostEquals, assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  type AvailabilityRow,
  approxHome,
  distanceKm,
  rankStoresForItem,
  toCandidates,
} from "./restockAvailabilityData.ts";

const row = (
  store_key: string,
  in_stock: boolean,
  age_days: number | string,
  lat: number | null = null,
  lng: number | null = null,
): AvailabilityRow => ({ store_key, in_stock, age_days, area_lat: lat, area_lng: lng });

Deno.test("distance: same point 0, nearby points a few km", () => {
  assertEquals(distanceKm({ lat: 30, lng: 31 }, { lat: 30, lng: 31 }), 0);
  const d = distanceKm({ lat: 30.04, lng: 31.23 }, { lat: 30.01, lng: 31.21 });
  assert(d > 3 && d < 5, `got ${d}`);
});

Deno.test("home is rounded before use", () => {
  assertEquals(approxHome({ lat: 30.04567, lng: 31.23891 }), { lat: 30.05, lng: 31.24 });
});

Deno.test("groups rows per store, numeric strings accepted, bad ages dropped", () => {
  const c = toCandidates([
    row("A", true, "1.5", 30.04, 31.23),
    row("A", false, 3),
    row("B", true, "oops"),
    row("C", true, 0),
  ], "لبن");
  const a = c.find((x) => x.storeId === "A")!;
  assertEquals(a.obs, [{ inStock: true, ageDays: 1.5 }, { inStock: false, ageDays: 3 }]);
  assertEquals(c.find((x) => x.storeId === "B"), undefined);
  assertEquals(a.item, "لبن");
});

Deno.test("no store area -> unknown distance, sorted last on ties", async () => {
  const sb = {
    rpc: () => Promise.resolve({ data: [row("far", true, 0), row("near", true, 0, 30.04, 31.23)], error: null }),
  };
  const r = await rankStoresForItem(sb, { country: "EG", item: "لبن", home: { lat: 30.0412, lng: 31.2299 } });
  assertEquals(r.map((x) => x.storeId), ["near", "far"]);
  assertAlmostEquals(r[0].distanceKm, 0, 1e-9);
});

Deno.test("ranks by probability, passes args, honours limit", async () => {
  let called: { fn: string; args: Record<string, unknown> } | undefined;
  const sb = {
    rpc: (fn: string, args: Record<string, unknown>) => {
      called = { fn, args };
      return Promise.resolve({
        data: [row("out", false, 0), row("in", true, 0), row("old", false, 60)],
        error: null,
      });
    },
  };
  const r = await rankStoresForItem(sb, { country: "EG", item: "رز", limit: 2 });
  assertEquals(called, { fn: "zad_restock_availability", args: { p_country: "EG", p_item_key: "رز", p_max_age_days: 90 } });
  assertEquals(r.map((x) => x.storeId), ["in", "old"]);
});

Deno.test("output carries no person or source field", async () => {
  const sb = { rpc: () => Promise.resolve({ data: [row("A", true, 0)], error: null }) };
  const r = await rankStoresForItem(sb, { country: "EG", item: "x" });
  assertEquals(Object.keys(r[0]).sort(), ["distanceKm", "item", "prob", "storeId"]);
});

Deno.test("rpc error throws, empty data gives empty list", async () => {
  await assertRejects(
    () => rankStoresForItem({ rpc: () => Promise.resolve({ data: null, error: { message: "boom" } }) }, { country: "EG", item: "x" }),
    Error,
    "boom",
  );
  assertEquals(await rankStoresForItem({ rpc: () => Promise.resolve({ data: null, error: null }) }, { country: "EG", item: "x" }), []);
});
