import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { type AskedToday, MAX_QUESTIONS_PER_DAY, pickTripQuestion, type TripQuestion, windowAt } from "./tripCheckIn.ts";

const L1: TripQuestion = { id: "lunch-a", window: "lunch", value: 1, cost: 1 };
const L2: TripQuestion = { id: "lunch-b", window: "lunch", value: 2, cost: 2 };
const E1: TripQuestion = { id: "eve-a", window: "evening", value: 1, cost: 1 };
const ALL = [L1, L2, E1];

Deno.test("window edges: start inclusive, end exclusive", () => {
  assertEquals(windowAt(12.99), null);
  assertEquals(windowAt(13), "lunch");
  assertEquals(windowAt(14.99), "lunch");
  assertEquals(windowAt(15), null);
  assertEquals(windowAt(19.99), null);
  assertEquals(windowAt(20), "evening");
  assertEquals(windowAt(21.99), "evening");
  assertEquals(windowAt(22), null);
  assertEquals(windowAt(0), null);
});

Deno.test("invalid hour throws", () => {
  assertThrows(() => windowAt(24), RangeError);
  assertThrows(() => windowAt(-1), RangeError);
  assertThrows(() => windowAt(NaN), RangeError);
});

Deno.test("none outside windows", () => {
  for (const h of [3, 12, 15, 17, 22, 23]) assertEquals(pickTripQuestion(h, [], ALL, 10), null);
});

Deno.test("picks only questions of the current window, highest value", () => {
  assertEquals(pickTripQuestion(13, [], ALL, 10), L2);
  assertEquals(pickTripQuestion(20, [], ALL, 10), E1);
});

Deno.test("budget: affordable-only, zero budget asks nothing", () => {
  assertEquals(pickTripQuestion(14, [], ALL, 1), L1);
  assertEquals(pickTripQuestion(14, [], ALL, 2), L2);
  assertEquals(pickTripQuestion(14, [], ALL, 0), null);
});

Deno.test("daily cap of 2", () => {
  assertEquals(MAX_QUESTIONS_PER_DAY, 2);
  const two: AskedToday[] = [{ id: "x", window: "lunch" }, { id: "y", window: "evening" }];
  assertEquals(pickTripQuestion(21, [], ALL, 10), E1);
  assertEquals(pickTripQuestion(21, two, ALL, 10), null);
  const three: AskedToday[] = [...two, { id: "z", window: "lunch" }];
  assertEquals(pickTripQuestion(14, three, ALL, 10), null);
});

Deno.test("one question per window; evening still open after lunch", () => {
  const lunch: AskedToday[] = [{ id: "lunch-b", window: "lunch" }];
  assertEquals(pickTripQuestion(14, lunch, ALL, 10), null);
  assertEquals(pickTripQuestion(21, lunch, ALL, 10), E1);
});

Deno.test("already-asked ids are skipped", () => {
  const evening: AskedToday[] = [{ id: "eve-a", window: "evening" }];
  assertEquals(pickTripQuestion(21, evening, [E1, { ...E1, id: "eve-b" }], 10), null);
});

Deno.test("ties go to smaller id, deterministic and input untouched", () => {
  const a: TripQuestion = { id: "b", window: "lunch", value: 1, cost: 1 };
  const b: TripQuestion = { id: "a", window: "lunch", value: 1, cost: 1 };
  const input = [a, b];
  assertEquals(pickTripQuestion(13, [], input, 5), b);
  assertEquals(pickTripQuestion(13, [], [b, a], 5), b);
  assertEquals(input, [a, b]);
});

Deno.test("no candidates returns null; bad budget throws via attentionBudget", () => {
  assertEquals(pickTripQuestion(13, [], [], 5), null);
  assertThrows(() => pickTripQuestion(13, [], ALL, -1), RangeError);
});
