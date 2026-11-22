import { assert, assertAlmostEquals, assertEquals, assertThrows } from "jsr:@std/assert@1";
import { prob, rankNearby, weight } from "./restockAvailability.ts";

Deno.test("no observations -> 0.5", () => {
  assertEquals(prob([]), 0.5);
});

Deno.test("weight halves at half-life", () => {
  assertAlmostEquals(weight(7), 0.5, 1e-12);
  assertEquals(weight(0), 1);
  assertEquals(weight(-3), 1);
  assertThrows(() => weight(1, 0));
});

Deno.test("fresh in-stock raises, fresh out lowers", () => {
  assertAlmostEquals(prob([{ inStock: true, ageDays: 0 }]), 2 / 3, 1e-12);
  assertAlmostEquals(prob([{ inStock: false, ageDays: 0 }]), 1 / 3, 1e-12);
});

Deno.test("old observation decays toward prior", () => {
  const fresh = prob([{ inStock: true, ageDays: 0 }]);
  const old = prob([{ inStock: true, ageDays: 70 }]);
  assert(old < fresh && old > 0.5 && old < 0.502);
});

Deno.test("recent out-of-stock beats old in-stock", () => {
  const p = prob([
    { inStock: true, ageDays: 30 },
    { inStock: false, ageDays: 0 },
  ]);
  assert(p < 0.5);
});

Deno.test("rankNearby: prob desc then distance", () => {
  const r = rankNearby([
    { storeId: "far", item: "x", obs: [{ inStock: true, ageDays: 0 }], distanceKm: 5 },
    { storeId: "near", item: "x", obs: [{ inStock: true, ageDays: 0 }], distanceKm: 1 },
    { storeId: "bad", item: "x", obs: [{ inStock: false, ageDays: 0 }], distanceKm: 0.1 },
  ]);
  assertEquals(r.map((x) => x.storeId), ["near", "far", "bad"]);
  assertEquals(Object.keys(r[0]).sort(), ["distanceKm", "item", "prob", "storeId"]);
});
