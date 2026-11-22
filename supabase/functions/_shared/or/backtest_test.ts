import { assert, assertEquals, assertNotEquals, assertThrows } from "jsr:@std/assert@1";
import {
  backtest,
  type BacktestEvent,
  compareBacktests,
  generateHousehold,
  generateHouseholds,
  type Persona,
  type Predictor,
} from "./backtest.ts";

const persona: Persona = { id: "p1", householdSize: 4, ratePerPersonPerDay: 2, intermittency: 0.2, days: 60 };
const meanPredictor: Predictor = (h) => {
  const m = h.reduce((s, e) => s + e.value, 0) / Math.max(1, h.length);
  return { predicted: m };
};

Deno.test("perfect predictor (oracle) gives zero error", () => {
  const hh = generateHousehold(persona, 1);
  const byT = new Map(hh.events.map((e) => [e.t, e.value]));
  const oracle: Predictor = (_h, t) => ({ predicted: byT.get(t)!, low: byT.get(t)!, high: byT.get(t)! });
  const r = backtest([hh], oracle);
  assertEquals(r.aggregate.mae, 0);
  assertEquals(r.aggregate.mape, 0);
  assertEquals(r.aggregate.coverage, 1);
  assertEquals(r.aggregate.n, 53);
});

Deno.test("MAPE skips zero actuals; null when all zero", () => {
  const zero = { id: "z", events: Array.from({ length: 10 }, (_, t) => ({ t, value: 0 })) };
  const r = backtest([zero], () => ({ predicted: 1 }));
  assertEquals(r.aggregate.mape, null);
  assertEquals(r.aggregate.mapeSkipped, 3);
  assertEquals(r.aggregate.mae, 1);
});

Deno.test("candidate better than baseline feeds modelGate; worse candidate is rejected", () => {
  const hhs = generateHouseholds([persona, { ...persona, id: "p2", householdSize: 2 }], 5);
  const bad: Predictor = () => ({ predicted: 0 });
  const good = compareBacktests(hhs, { version: "mean", predict: meanPredictor }, { version: "zero", predict: bad });
  assert(good.maeImprovement! > 0);
  assertEquals(good.householdsImproved, 2);
  assertEquals(good.decision?.deploy, true);
  assertEquals(good.candidateStats.n, 106);
  const worse = compareBacktests(hhs, { version: "zero", predict: bad }, { version: "mean", predict: meanPredictor });
  assertEquals(worse.decision?.deploy, false);
  assertEquals(worse.householdsImproved, 0);
});

Deno.test("small sample is not deployed even if better", () => {
  const hh = generateHousehold({ ...persona, days: 12 }, 3);
  const r = compareBacktests([hh], { version: "a", predict: meanPredictor }, { version: "b", predict: () => ({ predicted: 0 }) });
  assertEquals(r.decision?.deploy, false);
});

Deno.test("no look-ahead: predictor only sees events strictly before t and cannot mutate", () => {
  const hh = generateHousehold(persona, 9);
  let calls = 0;
  const spy: Predictor = (history, t) => {
    calls++;
    assert(history.length > 0);
    for (const e of history) assert(e.t < t, `leak: ${e.t} >= ${t}`);
    assertEquals(history.length, hh.events.findIndex((e) => e.t === t));
    assertThrows(() => (history as BacktestEvent[]).push({ t, value: 1 }));
    return { predicted: 0 };
  };
  backtest([hh], spy);
  assertEquals(calls, 53);
  assertEquals(hh.events.length, 60);
});

Deno.test("determinism by seed", () => {
  assertEquals(generateHousehold(persona, 42), generateHousehold(persona, 42));
  assertNotEquals(generateHousehold(persona, 42).events, generateHousehold(persona, 43).events);
  const a = backtest([generateHousehold(persona, 42)], meanPredictor);
  const b = backtest([generateHousehold(persona, 42)], meanPredictor);
  assertEquals(a, b);
});

Deno.test("persona params shape the series; invalid input throws", () => {
  const dense = generateHousehold({ ...persona, intermittency: 0, noise: 0 }, 1);
  assert(dense.events.every((e) => e.value === 8));
  const never = generateHousehold({ ...persona, intermittency: 1 }, 1);
  assert(never.events.every((e) => e.value === 0));
  assertThrows(() => generateHousehold({ ...persona, intermittency: 2 }, 1), RangeError);
  assertThrows(() => backtest([{ id: "x", events: [{ t: 2, value: 1 }, { t: 1, value: 1 }] }], meanPredictor), RangeError);
});

Deno.test("interval coverage is reported when predictor gives bounds", () => {
  const hh = generateHousehold({ ...persona, intermittency: 0, noise: 0 }, 1);
  const r = backtest([hh], () => ({ predicted: 8, low: 7, high: 9 }));
  assertEquals(r.aggregate.coverage, 1);
  const miss = backtest([hh], () => ({ predicted: 8, low: 0, high: 1 }));
  assertEquals(miss.aggregate.coverage, 0);
});
