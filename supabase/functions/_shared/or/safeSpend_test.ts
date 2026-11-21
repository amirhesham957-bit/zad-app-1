import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  DEFAULT_PATHS,
  MIN_HISTORY_DAYS,
  mulberry32,
  safeSpendToday,
} from "./safeSpend.ts";

Deno.test("1. perDay: available 3000, obligations 1000, margin 200, 10 days -> 180", () => {
  const input = {
    available: 3000,
    obligationsUntilPayday: 1000,
    margin: 200,
    daysUntilPayday: 10,
    spendHistory: [],
  };
  const result = safeSpendToday(input);
  assertEquals(result.perDay, 180);
});

Deno.test("2. Over-committed (available 500, obligations 1000) -> perDay 0, never negative", () => {
  const input = {
    available: 500,
    obligationsUntilPayday: 1000,
    margin: 200,
    daysUntilPayday: 10,
    spendHistory: [],
  };
  const result = safeSpendToday(input);
  assertEquals(result.perDay, 0);
});

Deno.test("3. daysUntilPayday 0 and 0.4 are treated as 1 day", () => {
  const input1 = {
    available: 1000,
    obligationsUntilPayday: 0,
    margin: 0,
    daysUntilPayday: 0,
    spendHistory: [],
  };
  assertEquals(safeSpendToday(input1).perDay, 1000);

  const input2 = {
    available: 1000,
    obligationsUntilPayday: 0,
    margin: 0,
    daysUntilPayday: 0.4,
    spendHistory: [],
  };
  assertEquals(safeSpendToday(input2).perDay, 1000);
});

Deno.test("4. 13 days of history -> approximate true, reachProbability null, paths 0", () => {
  const input = {
    available: 1000,
    obligationsUntilPayday: 0,
    margin: 0,
    daysUntilPayday: 10,
    spendHistory: new Array(13).fill(10),
  };
  const result = safeSpendToday(input);
  assertEquals(result.approximate, true);
  assertEquals(result.reachProbability, null);
  assertEquals(result.paths, 0);
});

Deno.test("5. 14 days all equal to 10, 5 days to payday, available - obligations = 100 -> reachProbability 1", () => {
  const input = {
    available: 100,
    obligationsUntilPayday: 0,
    margin: 0,
    daysUntilPayday: 5,
    spendHistory: new Array(14).fill(10),
  };
  const result = safeSpendToday(input);
  assertEquals(result.reachProbability, 1);
});

Deno.test("6. Same but available - obligations = 40 -> reachProbability 0", () => {
  const input = {
    available: 40,
    obligationsUntilPayday: 0,
    margin: 0,
    daysUntilPayday: 5,
    spendHistory: new Array(14).fill(10),
  };
  const result = safeSpendToday(input);
  assertEquals(result.reachProbability, 0);
});

Deno.test("6b. The margin is not subtracted inside Monte Carlo, and spending exactly the limit still reaches payday", () => {
  const base = { obligationsUntilPayday: 0, daysUntilPayday: 5, spendHistory: new Array(14).fill(10) };
  assertEquals(safeSpendToday({ ...base, available: 60, margin: 20 }).reachProbability, 1);
  assertEquals(safeSpendToday({ ...base, available: 50, margin: 0 }).reachProbability, 1);
});

Deno.test("7. Mixed history, same seed twice -> identical results; a different seed may differ but stays in [0, 1]", () => {
  const spendHistory = [
    10,
    20,
    30,
    40,
    50,
    60,
    70,
    80,
    90,
    100,
    110,
    120,
    130,
    140,
  ];
  const input = {
    available: 500,
    obligationsUntilPayday: 0,
    margin: 0,
    daysUntilPayday: 5,
    spendHistory,
  };
  const result1 = safeSpendToday(input, { seed: 42 });
  const result2 = safeSpendToday(input, { seed: 42 });
  const result3 = safeSpendToday(input, { seed: 43 });

  assertEquals(result1.reachProbability, result2.reachProbability);
  // reachProbability stays in [0, 1]
  assertEquals(
    result1.reachProbability! >= 0 && result1.reachProbability! <= 1,
    true,
  );
  assertEquals(
    result3.reachProbability! >= 0 && result3.reachProbability! <= 1,
    true,
  );
});

Deno.test("8. mulberry32(42) first 5 values are all in [0, 1) and repeat for a fresh mulberry32(42)", () => {
  const rng1 = mulberry32(42);
  const vals1 = [rng1(), rng1(), rng1(), rng1(), rng1()];

  vals1.forEach((v) => {
    assertEquals(v >= 0 && v < 1, true);
  });

  const rng2 = mulberry32(42);
  const vals2 = [rng2(), rng2(), rng2(), rng2(), rng2()];
  assertEquals(vals1, vals2);
});

Deno.test("9. NaN available, negative margin and a negative history value each throw RangeError", () => {
  assertThrows(
    () =>
      safeSpendToday({
        available: NaN,
        obligationsUntilPayday: 0,
        margin: 0,
        daysUntilPayday: 10,
        spendHistory: [],
      }),
    RangeError,
  );

  assertThrows(
    () =>
      safeSpendToday({
        available: 1000,
        obligationsUntilPayday: 0,
        margin: -1,
        daysUntilPayday: 10,
        spendHistory: [],
      }),
    RangeError,
  );

  assertThrows(
    () =>
      safeSpendToday({
        available: 1000,
        obligationsUntilPayday: 0,
        margin: 0,
        daysUntilPayday: 10,
        spendHistory: [-10],
      }),
    RangeError,
  );
});
