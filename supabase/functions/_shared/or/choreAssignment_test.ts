import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { assignChores, DISLIKE_PENALTY, hungarian } from "./choreAssignment.ts";

function totalCost(cost: readonly (readonly number[])[], assign: readonly number[]): number {
  return cost.reduce((sum, row, r) => assign[r] < 0 ? sum : sum + row[assign[r]], 0);
}

Deno.test("hungarian finds the minimum total cost and a permutation", () => {
  const cost = [[4, 1, 3], [2, 0, 5], [3, 2, 2]];
  const assign = hungarian(cost);
  assertEquals(totalCost(cost, assign), 5);
  assertEquals([...assign].sort((a, b) => a - b), [0, 1, 2]);
});

Deno.test("hungarian solves the classic four-by-four example", () => {
  const cost = [[9, 2, 7, 8], [6, 4, 3, 7], [5, 8, 1, 8], [7, 6, 9, 4]];
  const assign = hungarian(cost);
  assertEquals(assign, [1, 0, 2, 3]);
  assertEquals(totalCost(cost, assign), 13);
});

Deno.test("hungarian handles more jobs than workers", () => {
  assertEquals(hungarian([[1, 2, 3], [3, 1, 2]]), [0, 1]);
});

Deno.test("hungarian handles more workers than jobs", () => {
  const assign = hungarian([[1, 2], [3, 1], [2, 2]]);
  assertEquals(assign.length, 3);
  assertEquals(assign.filter((column) => column === -1).length, 1);
});

Deno.test("hungarian avoids the greedy trap", () => {
  const cost = [[1, 2], [1, 100]];
  const assign = hungarian(cost);
  assertEquals(assign, [1, 0]);
  assertEquals(totalCost(cost, assign), 3);
});

Deno.test("hungarian allows negative costs", () => {
  const cost = [[-5, 0], [0, -5]];
  assertEquals(totalCost(cost, hungarian(cost)), -10);
});

Deno.test("assignChores sends a disliked equal-length chore to another member", () => {
  const plan = assignChores(
    [{ id: "dishes", minutes: 10 }, { id: "laundry", minutes: 10 }],
    [
      { id: "picky", minutesBudget: 20, dislikes: ["dishes"] },
      { id: "helper", minutesBudget: 20 },
    ],
  );
  assertEquals(plan, {
    assignments: [
      { choreId: "dishes", memberId: "helper" },
      { choreId: "laundry", memberId: "picky" },
    ],
    unassigned: [],
    totalCost: 20,
  });
  assertEquals(DISLIKE_PENALTY, 30);
});

Deno.test("assignChores leaves a chore over every budget unassigned", () => {
  const plan = assignChores(
    [{ id: "too-long", minutes: 60 }],
    [{ id: "one", minutesBudget: 10 }, { id: "two", minutesBudget: 20 }],
  );
  assertEquals(plan, { assignments: [], unassigned: ["too-long"], totalCost: 0 });
});

Deno.test("assignChores leaves extra chores unassigned", () => {
  const plan = assignChores(
    [{ id: "one", minutes: 5 }, { id: "two", minutes: 6 }, { id: "three", minutes: 7 }],
    [{ id: "first", minutesBudget: 10 }, { id: "second", minutesBudget: 10 }],
  );
  assertEquals(plan.assignments.length, 2);
  assertEquals(plan.unassigned, ["three"]);
  assertEquals(plan.totalCost, 11);
});

Deno.test("assignChores assigns every chore when members are plentiful", () => {
  const plan = assignChores(
    [{ id: "only", minutes: 5 }],
    [{ id: "first", minutesBudget: 10 }, { id: "second", minutesBudget: 10 }],
  );
  assertEquals(plan.assignments, [{ choreId: "only", memberId: "first" }]);
  assertEquals(plan.unassigned, []);
  assertEquals(plan.totalCost, 5);
});

Deno.test("hungarian rejects ragged matrices", () => {
  assertThrows(() => hungarian([[1], [2, 3]]), RangeError);
});

Deno.test("hungarian rejects non-finite costs", () => {
  assertThrows(() => hungarian([[1, NaN], [2, 3]]), RangeError);
  assertThrows(() => hungarian([[1, Infinity], [2, 3]]), RangeError);
});

Deno.test("assignChores rejects duplicate member ids", () => {
  assertThrows(
    () =>
      assignChores(
        [{ id: "chore", minutes: 1 }],
        [{ id: "same", minutesBudget: 2 }, { id: "same", minutesBudget: 2 }],
      ),
    RangeError,
  );
});

Deno.test("assignChores rejects a negative budget", () => {
  assertThrows(
    () => assignChores([{ id: "chore", minutes: 1 }], [{ id: "member", minutesBudget: -1 }]),
    RangeError,
  );
});

Deno.test("assignChores rejects duplicate chore ids and invalid numbers", () => {
  assertThrows(
    () => assignChores([{ id: "same", minutes: 1 }, { id: "same", minutes: 2 }], []),
    RangeError,
  );
  assertThrows(() => assignChores([{ id: "negative", minutes: -1 }], []), RangeError);
  assertThrows(() => assignChores([{ id: "infinite", minutes: Infinity }], []), RangeError);
});

Deno.test("an over-budget member is never the 'cheap' choice: the chore goes to whoever has the time", () => {
  // Y dislikes A, so ignoring budgets the cheapest plan is A→X + B→Y (70). But A (60 min) doesn't fit X's 30,
  // so the only plan that keeps both chores is A→Y + B→X.
  const plan = assignChores(
    [{ id: "A", minutes: 60 }, { id: "B", minutes: 10 }],
    [{ id: "X", minutesBudget: 30 }, { id: "Y", minutesBudget: 90, dislikes: ["A"] }],
  );
  assertEquals(plan.assignments, [{ choreId: "A", memberId: "Y" }, { choreId: "B", memberId: "X" }]);
  assertEquals(plan.unassigned, []);
  assertEquals(plan.totalCost, 100);
});
