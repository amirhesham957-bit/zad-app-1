// يتعلم من النتيجة (ZAD_PLAN ٣.٦).
import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  LEARN_MIN_SENT, LEARNED_QUIET_GAP_DAYS, learnedPriority, learnedQuietUntil, outcomesByKind, stanceOf, type KindOutcome,
} from "./outcomeLearning.ts";
import { HOLD_REASON_AR } from "./shared.ts";

const o = (sent: number, acted: number): KindOutcome => ({ kind: "spend_forecast", sent, replied: 0, acted, dismissed: 0, last_at: null });
const NOW = Date.parse("2026-10-25T10:00:00Z");
const DAY = 86_400_000;

Deno.test("a kind ignored ten times goes quiet for this home; nine is not enough to judge", () => {
  assertEquals(stanceOf(o(10, 0)), "quiet");
  assertEquals(stanceOf(o(12, 1)), "quiet"); // 8%
  assertEquals(stanceOf(o(10, 1)), "normal"); // 10% is not under 10%
  assertEquals(stanceOf(o(LEARN_MIN_SENT - 1, 0)), "normal");
});

Deno.test("a kind that works is welcomed; no history is normal", () => {
  assertEquals(stanceOf(o(5, 3)), "welcomed");
  assertEquals(stanceOf(o(4, 4)), "normal");
  assertEquals(stanceOf(null), "normal");
  assertEquals(stanceOf(o(0, 0)), "normal");
});

Deno.test("a welcomed kind takes a slot before its equals, never before a more important one", () => {
  assert(learnedPriority(2, "welcomed") < learnedPriority(2, "normal"));
  assert(learnedPriority(2, "normal") < learnedPriority(2, "quiet"));
  assert(learnedPriority(1, "quiet") < learnedPriority(2, "welcomed"));
});

Deno.test("a quiet kind waits for the week since it last reached them, then goes", () => {
  const sent2 = NOW - 2 * DAY;
  assertEquals(learnedQuietUntil("quiet", sent2, NOW), new Date(sent2 + LEARNED_QUIET_GAP_DAYS * DAY).toISOString());
  assertEquals(learnedQuietUntil("quiet", NOW - 8 * DAY, NOW), null);
  assertEquals(learnedQuietUntil("quiet", null, NOW), null);
  assertEquals(learnedQuietUntil("normal", sent2, NOW), null);
  assertEquals(learnedQuietUntil("welcomed", sent2, NOW), null);
});

Deno.test("rows from the database read as numbers, and a kind-less row is dropped", () => {
  const m = outcomesByKind([
    { kind: "habit_budget", sent: "11", replied: "2", acted: "0", dismissed: 1, last_at: "2026-10-20T08:00:00Z" },
    { kind: "", sent: 3 },
  ]);
  assertEquals(m.size, 1);
  assertEquals(m.get("habit_budget"), { kind: "habit_budget", sent: 11, replied: 2, acted: 0, dismissed: 1, last_at: "2026-10-20T08:00:00Z" });
  assertEquals(stanceOf(m.get("habit_budget")), "quiet");
});

Deno.test("the learned hold has words for «what you didn't tell me»", () => {
  assert(HOLD_REASON_AR.learned_quiet.length > 0);
});
