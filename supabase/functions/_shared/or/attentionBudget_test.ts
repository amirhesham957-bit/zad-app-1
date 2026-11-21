import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { type Candidate, planMessages } from "./attentionBudget.ts";

const c = (id: string, value: number, cost: number, critical = false): Candidate => ({ id, value, cost, critical });

Deno.test("best pair within budget beats the single most valuable", () => {
  assertEquals(planMessages([c("a", 6, 2), c("b", 10, 3), c("c", 12, 4)], 5), {
    send: ["a", "b"],
    deferred: ["c"],
    used: 5,
    value: 16,
  });
});

Deno.test("greedy-by-value trap: exact DP picks y+z, not x", () => {
  const plan = planMessages([c("x", 10, 4), c("y", 7, 2), c("z", 7, 2)], 4);
  assertEquals(plan.send, ["y", "z"]);
  assertEquals(plan.value, 14);
});

Deno.test("critical goes out with zero budget and spends nothing", () => {
  assertEquals(planMessages([c("d", 1, 10, true)], 0), { send: ["d"], deferred: [], used: 0, value: 0 });
});

Deno.test("a valuable critical message does not crowd out the budget", () => {
  const plan = planMessages([c("crit", 100, 2, true), c("a", 5, 2)], 2);
  assertEquals(plan.send, ["crit", "a"]);
  assertEquals(plan.used, 2);
  assertEquals(plan.value, 5);
});

Deno.test("zero budget and nothing critical sends nothing", () => {
  assertEquals(planMessages([c("a", 5, 1), c("b", 3, 2)], 0), { send: [], deferred: ["a", "b"], used: 0, value: 0 });
});

Deno.test("send keeps input order across critical and chosen", () => {
  const plan = planMessages([c("a", 5, 1), c("crit", 0, 9, true), c("b", 1, 5), c("d", 4, 1)], 2);
  assertEquals(plan.send, ["a", "crit", "d"]);
  assertEquals(plan.deferred, ["b"]);
  assertEquals(plan.used, 2);
});

Deno.test("deterministic: same input, same plan; ties keep the earlier candidate", () => {
  const input = [c("p", 5, 2), c("q", 5, 2), c("r", 1, 1)];
  assertEquals(planMessages(input, 2), planMessages(input, 2));
  assertEquals(planMessages(input, 2).send, ["p"]);
});

Deno.test("invalid input throws RangeError", () => {
  assertThrows(() => planMessages([c("a", 1, 1.5)], 3), RangeError);
  assertThrows(() => planMessages([c("a", 1, 0)], 3), RangeError);
  assertThrows(() => planMessages([c("a", -1, 1)], 3), RangeError);
  assertThrows(() => planMessages([c("a", 1, 1)], 2.5), RangeError);
  assertThrows(() => planMessages([c("a", 1, 1), c("a", 2, 1)], 3), RangeError);
});
