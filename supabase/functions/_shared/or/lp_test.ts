import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { type LpModel, solveLp, toLpText } from "./lp.ts";

const validModel = (): LpModel => ({
  sense: "max",
  objective: { x: 1 },
  vars: [{ name: "x" }],
  constraints: [],
});

Deno.test("toLpText emits CPLEX sections and integer declarations", () => {
  const text = toLpText({
    sense: "max",
    objective: { x: 1, y: 2 },
    vars: [{ name: "x", ub: 1, integer: true }, { name: "y" }],
    constraints: [{ name: "capacity", terms: { x: 1, y: 1 }, op: "<=", rhs: 4 }],
  });
  for (const section of ["Maximize", "Subject To", "Bounds", "End"]) {
    assertEquals(text.includes(section), true, section);
  }
  assertEquals(text.includes("General\n  x\nEnd"), true);
});

Deno.test("toLpText rejects every invalid input with RangeError", () => {
  assertThrows(() => toLpText({ ...validModel(), vars: [{ name: "1x" }] }), RangeError);
  assertThrows(() => toLpText({ ...validModel(), vars: [{ name: "x" }, { name: "x" }] }), RangeError);
  assertThrows(() => toLpText({ ...validModel(), objective: { y: 1 } }), RangeError);
  assertThrows(() =>
    toLpText({
      ...validModel(),
      constraints: [{ name: "bad", terms: { y: 1 }, op: "<=", rhs: 1 }],
    }), RangeError);
  assertThrows(() => toLpText({ ...validModel(), objective: { x: Infinity } }), RangeError);
  assertThrows(() =>
    toLpText({
      ...validModel(),
      constraints: [{ name: "bad", terms: { x: NaN }, op: "<=", rhs: 1 }],
    }), RangeError);
  assertThrows(() =>
    toLpText({
      ...validModel(),
      constraints: [{ name: "bad", terms: { x: 1 }, op: "<=", rhs: Infinity }],
    }), RangeError);
  assertThrows(() => toLpText({ ...validModel(), vars: [{ name: "x", lb: 2, ub: 1 }] }), RangeError);
});

// Keep this as the first solver test so first_ms includes the initial WASM load.
Deno.test("200-item binary knapsack cold and warm performance probe", async () => {
  const vars = Array.from({ length: 200 }, (_, i) => ({ name: `x${i}`, lb: 0, ub: 1, integer: true }));
  const model: LpModel = {
    sense: "max",
    objective: Object.fromEntries(vars.map((v, i) => [v.name, (i * 37 % 101) + 1])),
    vars,
    constraints: [{
      name: "capacity",
      terms: Object.fromEntries(vars.map((v, i) => [v.name, (i * 53 % 29) + 1])),
      op: "<=",
      rhs: 500,
    }],
  };

  const firstStart = performance.now();
  const first = await solveLp(model);
  const firstMs = performance.now() - firstStart;
  const warmStart = performance.now();
  const warm = await solveLp(model);
  const warmMs = performance.now() - warmStart;
  console.log(
    `highs-probe first_ms=${Math.round(firstMs)} warm_ms=${Math.round(warmMs)} rss_mb=${Math.round(Deno.memoryUsage().rss / 1e6)}`,
  );
  assertEquals(first.status, "optimal");
  assertEquals(warm.status, "optimal");
  assertEquals(warmMs < 2000, true, `warm solve took ${warmMs}ms`);
});

Deno.test("continuous LP reaches the optimal vertex", async () => {
  const result = await solveLp({
    sense: "max",
    objective: { x: 3, y: 2 },
    vars: [{ name: "x" }, { name: "y" }],
    constraints: [
      { name: "c1", terms: { x: 1, y: 1 }, op: "<=", rhs: 4 },
      { name: "c2", terms: { x: 1, y: 3 }, op: "<=", rhs: 6 },
      { name: "c3", terms: { x: 1 }, op: "<=", rhs: 3 },
    ],
  });
  assertEquals(result.status, "optimal");
  assertEquals(result.objective, 11);
  assertEquals(result.values, { x: 3, y: 1 });
});

Deno.test("MILP knapsack picks y and z instead of the greedy x", async () => {
  const result = await solveLp({
    sense: "max",
    objective: { x: 10, y: 7, z: 7 },
    vars: [
      { name: "x", lb: 0, ub: 1, integer: true },
      { name: "y", lb: 0, ub: 1, integer: true },
      { name: "z", lb: 0, ub: 1, integer: true },
    ],
    constraints: [{ name: "capacity", terms: { x: 4, y: 2, z: 2 }, op: "<=", rhs: 4 }],
  });
  assertEquals(result.status, "optimal");
  assertEquals(result.objective, 14);
  assertEquals(result.values, { x: 0, y: 1, z: 1 });
});

Deno.test("infeasible model has no objective", async () => {
  const result = await solveLp({
    sense: "max",
    objective: { x: 1 },
    vars: [{ name: "x" }],
    constraints: [
      { name: "lower", terms: { x: 1 }, op: ">=", rhs: 5 },
      { name: "upper", terms: { x: 1 }, op: "<=", rhs: 3 },
    ],
  });
  assertEquals(result.status, "infeasible");
  assertEquals(result.objective, null);
});

Deno.test("unbounded model is not reported optimal", async () => {
  const result = await solveLp({
    sense: "max",
    objective: { x: 1 },
    vars: [{ name: "x" }],
    constraints: [],
  });
  assertEquals(result.status === "optimal", false);
});
