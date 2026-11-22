import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { shouldDeploy } from "./modelGate.ts";

const current = { version: "v1", mae: 2.0, n: 100 };

Deno.test("deploys a better candidate with enough samples", () => {
  const decision = shouldDeploy(
    { version: "v2", mae: 1.5, n: 50 },
    current,
  );

  assertEquals(decision.deploy, true);
  assertEquals(typeof decision.reason, "string");
});

Deno.test("never deploys an equal candidate", () => {
  const decision = shouldDeploy(
    { version: "v2", mae: 2.0, n: 500 },
    current,
  );

  assertEquals(decision.deploy, false);
});

Deno.test("never deploys a worse candidate", () => {
  const decision = shouldDeploy(
    { version: "v2", mae: 2.5, n: 500 },
    current,
  );

  assertEquals(decision.deploy, false);
});

Deno.test("never deploys a candidate with small n even if better", () => {
  const decision = shouldDeploy(
    { version: "v2", mae: 0.1, n: 29 },
    current,
  );

  assertEquals(decision.deploy, false);
});

Deno.test("respects a custom minN", () => {
  const decision = shouldDeploy(
    { version: "v2", mae: 1.0, n: 10 },
    current,
    { minN: 10 },
  );

  assertEquals(decision.deploy, true);
});

Deno.test("rejects non-finite or negative inputs", () => {
  assertThrows(
    () => shouldDeploy({ version: "v2", mae: NaN, n: 50 }, current),
    RangeError,
  );
  assertThrows(
    () => shouldDeploy({ version: "v2", mae: 1, n: Infinity }, current),
    RangeError,
  );
  assertThrows(
    () =>
      shouldDeploy({ version: "v2", mae: 1, n: 50 }, {
        version: "v1",
        mae: -1,
        n: 100,
      }),
    RangeError,
  );
  assertThrows(
    () => shouldDeploy({ version: "v2", mae: 1, n: 50 }, current, { minN: -1 }),
    RangeError,
  );
});

Deno.test("margin: improvement below margin is rejected", () => {
  const d = shouldDeploy({ version: "v2", mae: 1.9, n: 100 }, current, {
    margin: 0.1,
  });
  assertEquals(d.deploy, false);
});

Deno.test("margin: improvement at or above margin deploys", () => {
  const d = shouldDeploy({ version: "v2", mae: 1.7, n: 100 }, current, {
    margin: 0.1,
  });
  assertEquals(d.deploy, true);
});

Deno.test("margin: invalid values throw", () => {
  assertThrows(
    () =>
      shouldDeploy({ version: "v2", mae: 1, n: 100 }, current, { margin: 1 }),
    RangeError,
  );
  assertThrows(
    () =>
      shouldDeploy({ version: "v2", mae: 1, n: 100 }, current, {
        margin: -0.1,
      }),
    RangeError,
  );
});
