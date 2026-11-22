import { assert, assertEquals } from "jsr:@std/assert@1";
import { type BasketInput, planBasket } from "./basketMilp.ts";

const offer = (price: number) => ({ price });

Deno.test("single store wins because of the delivery fee", async () => {
  const r = await planBasket({
    items: [{ name: "a", qty: 1 }, { name: "b", qty: 1 }],
    stores: [
      { name: "S1", offers: { a: offer(10), b: offer(10) }, deliveryFee: 5 },
      { name: "S2", offers: { a: offer(9), b: offer(12) }, deliveryFee: 5 },
    ],
  });
  assertEquals(r.path, "milp");
  assertEquals(r.storesUsed, ["S1"]);
  assertEquals(r.total, 25);
});

Deno.test("split across stores wins when savings beat the fee", async () => {
  const r = await planBasket({
    items: [{ name: "a", qty: 1 }, { name: "b", qty: 1 }],
    stores: [
      { name: "S1", offers: { a: offer(10), b: offer(50) }, deliveryFee: 2 },
      { name: "S2", offers: { a: offer(40), b: offer(10) }, deliveryFee: 2 },
    ],
  });
  assertEquals(r.path, "milp");
  assertEquals(r.storesUsed.sort(), ["S1", "S2"]);
  assertEquals(r.total, 24);
});

Deno.test("minimum order forces consolidation", async () => {
  const r = await planBasket({
    items: [{ name: "a", qty: 1 }, { name: "b", qty: 1 }],
    stores: [
      { name: "S1", offers: { a: offer(10), b: offer(30) }, minOrder: 20 },
      { name: "S2", offers: { a: offer(11), b: offer(20) } },
    ],
  });
  assertEquals(r.path, "milp");
  // a alone at S1 (10) violates min 20; S1 for both = 40, S2 for both = 31
  assertEquals(r.storesUsed, ["S2"]);
  assertEquals(r.total, 31);
  assertEquals(r.minOrderViolations, []);
});

Deno.test("unreachable min order falls back to greedy and flags the violation", async () => {
  const r = await planBasket({
    items: [{ name: "a", qty: 1 }],
    stores: [
      { name: "S1", offers: { a: offer(10) }, minOrder: 100 },
      { name: "S2", offers: { a: offer(12) }, minOrder: 100 },
    ],
  });
  assertEquals(r.path, "greedy");
  assertEquals(r.fallbackReason, "solver_infeasible");
  assertEquals(r.minOrderViolations, ["S1"]);
});

Deno.test("unavailable item is reported and the rest still planned", async () => {
  const r = await planBasket({
    items: [{ name: "a", qty: 1 }, { name: "ghost", qty: 1 }, { name: "b", qty: 1 }],
    stores: [
      { name: "S1", offers: { a: offer(5), b: offer(5), ghost: { price: 3, available: false } } },
      { name: "S2", offers: { a: offer(6), b: offer(4) } },
    ],
  });
  assertEquals(r.unavailable, ["ghost"]);
  assertEquals(r.path, "milp");
  assertEquals(r.lines.length, 2);
});

Deno.test("fewer than two stores covering an item uses the greedy fallback", async () => {
  const r = await planBasket({
    items: [{ name: "a", qty: 2 }],
    stores: [{ name: "S1", offers: { a: offer(5) } }, { name: "S2", offers: {} }],
  });
  assertEquals(r.path, "greedy");
  assertEquals(r.fallbackReason, "thin_price_data");
  assertEquals(r.total, 10);
});

Deno.test("maxStores caps the number of stores", async () => {
  const r = await planBasket({
    items: [{ name: "a", qty: 1 }, { name: "b", qty: 1 }],
    stores: [
      { name: "S1", offers: { a: offer(1), b: offer(50) } },
      { name: "S2", offers: { a: offer(50), b: offer(1) } },
      { name: "S3", offers: { a: offer(20), b: offer(20) } },
    ],
    maxStores: 1,
  });
  assertEquals(r.storesUsed.length, 1);
  assertEquals(r.total, 40);
});

function rng(seed: number) {
  let s = seed >>> 0;
  return () => (s = (Math.imul(s, 1664525) + 1013904223) >>> 0) / 2 ** 32;
}

function brute(full: BasketInput): number | null {
  // items nobody stocks are reported as unavailable and excluded, like the planner does
  const inp = {
    ...full,
    items: full.items.filter((it) => full.stores.some((s) => s.offers[it.name]?.price)),
  };
  const n = inp.items.length, m = inp.stores.length;
  let best: number | null = null;
  const choice: number[] = new Array(n).fill(0);
  const rec = (i: number) => {
    if (i === n) {
      const sub = new Array(m).fill(0);
      for (let k = 0; k < n; k++) {
        sub[choice[k]] += inp.stores[choice[k]].offers[inp.items[k].name].price! * inp.items[k].qty;
      }
      let total = 0, used = 0;
      for (let s = 0; s < m; s++) {
        if (!choice.includes(s)) continue;
        used++;
        if (sub[s] < (inp.stores[s].minOrder ?? 0)) return;
        total += sub[s] + (inp.stores[s].deliveryFee ?? 0);
      }
      if (inp.maxStores !== undefined && used > inp.maxStores) return;
      if (best === null || total < best) best = total;
      return;
    }
    for (let s = 0; s < m; s++) {
      if (inp.stores[s].offers[inp.items[i].name]?.price) {
        choice[i] = s;
        rec(i + 1);
      }
    }
  };
  rec(0);
  return best;
}

Deno.test("solver equals brute force on seeded random cases", async () => {
  const rand = rng(12345);
  let milpCases = 0;
  for (let t = 0; t < 40; t++) {
    const n = 2 + Math.floor(rand() * 3), m = 2 + Math.floor(rand() * 2);
    const items = Array.from({ length: n }, (_, i) => ({ name: `i${i}`, qty: 1 + Math.floor(rand() * 3) }));
    const stores = Array.from({ length: m }, (_, s) => {
      const offers: Record<string, { price: number }> = {};
      for (const it of items) if (rand() < 0.85) offers[it.name] = { price: 1 + Math.floor(rand() * 20) };
      return {
        name: `S${s}`,
        offers,
        deliveryFee: Math.floor(rand() * 15),
        minOrder: rand() < 0.4 ? Math.floor(rand() * 40) : 0,
      };
    });
    const inp: BasketInput = { items, stores, maxStores: rand() < 0.3 ? 1 + Math.floor(rand() * 2) : undefined };
    const r = await planBasket(inp);
    if (r.path !== "milp") continue;
    milpCases++;
    const b = brute(inp);
    assert(b !== null, `case ${t}: solver found a plan brute force says is impossible`);
    assertEquals(r.total, Math.round(b * 100) / 100, `case ${t}`);
    assertEquals(r.minOrderViolations, []);
  }
  assert(milpCases >= 10, `only ${milpCases} milp cases`);
});
