import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { infoValue, pickWeeklyQuestion, MIN_DAYS_BETWEEN_QUESTIONS } from "./checkInQuestion.ts";

Deno.test("1. rate 1, low 0.5, high 1.5, onHand 7, lastConfirmed 14, essential -> infoValue 1; same but not essential -> 0.5", () => {
  const c1 = { itemId: "1", rate: 1, low: 0.5, high: 1.5, onHand: 7, lastConfirmedDaysAgo: 14, essential: true };
  // uncertainty = min(3, (1.5-0.5)/1) = 1
  // urgency = 1 / (1 + (7/1)/7) = 1 / (1+1) = 0.5
  // staleness = min(1, 14/14) = 1
  // weight = 2
  // val = 1 * 0.5 * 1 * 2 = 1
  assertEquals(infoValue(c1), 1);

  const c2 = { ...c1, essential: false };
  // val = 1 * 0.5 * 1 * 1 = 0.5
  assertEquals(infoValue(c2), 0.5);
});

Deno.test("2. rate 0 -> 0", () => {
  const c = { itemId: "1", rate: 0, low: 0.5, high: 1.5, onHand: 7, lastConfirmedDaysAgo: 14, essential: true };
  assertEquals(infoValue(c), 0);
});

Deno.test("3. Uncertainty cap: rate 1, low 0, high 10 -> uncertainty treated as 3", () => {
  const c = { itemId: "1", rate: 1, low: 0, high: 10, onHand: 7, lastConfirmedDaysAgo: 14, essential: false };
  // uncertainty = min(3, (10-0)/1) = 3
  // urgency = 0.5
  // staleness = 1
  // weight = 1
  // val = 3 * 0.5 * 1 * 1 = 1.5
  assertEquals(infoValue(c), 1.5);
});

Deno.test("4. lastAskedDaysAgo 3 and 6.99 -> null; 7 and null -> a question", () => {
  const cands = [{ itemId: "1", rate: 1, low: 0.5, high: 1.5, onHand: 7, lastConfirmedDaysAgo: 14, essential: true }];
  assertEquals(pickWeeklyQuestion(cands, 3), null);
  assertEquals(pickWeeklyQuestion(cands, 6.99), null);
  assertEquals(pickWeeklyQuestion(cands, 7)?.itemIds, ["1"]);
  assertEquals(pickWeeklyQuestion(cands, null)?.itemIds, ["1"]);
});

Deno.test("5. Five valuable candidates, maxItems 3 -> exactly 3, highest values first", () => {
  const cands = [
    { itemId: "a", rate: 1, low: 0.5, high: 1, onHand: 7, lastConfirmedDaysAgo: 14, essential: false }, // val = 0.5 * 0.5 * 1 * 1 = 0.25
    { itemId: "b", rate: 1, low: 0.5, high: 2, onHand: 7, lastConfirmedDaysAgo: 14, essential: false }, // val = 1.5 * 0.5 * 1 * 1 = 0.75
    { itemId: "c", rate: 1, low: 0.5, high: 2.5, onHand: 7, lastConfirmedDaysAgo: 14, essential: false }, // val = 2 * 0.5 * 1 * 1 = 1.0
    { itemId: "d", rate: 1, low: 0.5, high: 3, onHand: 7, lastConfirmedDaysAgo: 14, essential: false }, // val = 2.5 * 0.5 * 1 * 1 = 1.25
    { itemId: "e", rate: 1, low: 0.5, high: 3.5, onHand: 7, lastConfirmedDaysAgo: 14, essential: false }, // val = 3 * 0.5 * 1 * 1 = 1.5
  ];
  const q = pickWeeklyQuestion(cands, null, 3);
  assertEquals(q?.itemIds, ["e", "d", "c"]);
  assertEquals(q?.values, [1.5, 1.25, 1.0]);
});

Deno.test("6. Equal values -> ordered by itemId ascending", () => {
  const cands = [
    { itemId: "z", rate: 1, low: 0.5, high: 1.5, onHand: 7, lastConfirmedDaysAgo: 14, essential: false }, // val 0.5
    { itemId: "a", rate: 1, low: 0.5, high: 1.5, onHand: 7, lastConfirmedDaysAgo: 14, essential: false }, // val 0.5
    { itemId: "m", rate: 1, low: 0.5, high: 1.5, onHand: 7, lastConfirmedDaysAgo: 14, essential: false }, // val 0.5
  ];
  const q = pickWeeklyQuestion(cands, null, 3);
  assertEquals(q?.itemIds, ["a", "m", "z"]);
});

Deno.test("7. All below minValue -> null. Empty list -> null", () => {
  const cands = [{ itemId: "1", rate: 1, low: 0.5, high: 0.55, onHand: 7, lastConfirmedDaysAgo: 14, essential: false }];
  // val = 0.05 * 0.5 * 1 * 1 = 0.025
  assertEquals(pickWeeklyQuestion(cands, null, 3, 0.05), null);
  assertEquals(pickWeeklyQuestion([], null), null);
});

Deno.test("9. Staleness caps at 14 days and scales below it; urgency follows days of stock left", () => {
  const base = { itemId: "1", rate: 1, low: 0.5, high: 1.5, onHand: 7, lastConfirmedDaysAgo: 14, essential: false };
  assertEquals(infoValue({ ...base, lastConfirmedDaysAgo: 28 }), 0.5);
  assertEquals(infoValue({ ...base, lastConfirmedDaysAgo: 7 }), 0.25);
  assertEquals(infoValue({ ...base, onHand: 0 }), 1);
  assertEquals(infoValue({ ...base, onHand: 14 }), 0.3333);
});

Deno.test("10. A value exactly at minValue is kept", () => {
  const c = { itemId: "1", rate: 1, low: 0.5, high: 0.6, onHand: 7, lastConfirmedDaysAgo: 14, essential: false };
  assertEquals(infoValue(c), 0.05);
  assertEquals(pickWeeklyQuestion([c], null, 3, 0.05)?.itemIds, ["1"]);
});

Deno.test("8. A negative onHand or NaN rate throws RangeError", () => {
  const c1 = { itemId: "1", rate: 1, low: 0.5, high: 1.5, onHand: -1, lastConfirmedDaysAgo: 14, essential: true };
  assertThrows(() => infoValue(c1), RangeError);

  const c2 = { itemId: "1", rate: NaN, low: 0.5, high: 1.5, onHand: 7, lastConfirmedDaysAgo: 14, essential: true };
  assertThrows(() => infoValue(c2), RangeError);
});
