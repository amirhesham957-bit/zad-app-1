import { assert, assertEquals } from "jsr:@std/assert@1";
import { memberGoalsEnabled, memberGoalView, weeklyProgress } from "./memberGoalWiring.ts";

const D = 86_400_000;
const t0 = Date.parse("2026-10-01T00:00:00Z");
const ev = (day: number, amount: number, id = "g1") => ({ occurred_at: new Date(t0 + day * D).toISOString(), payload: { row_id: id, amount } });
const goal = { id: "g1", title: "توفير", target_value: 1000, deadline_date: "2026-11-26", created_at: "2026-10-01T00:00:00Z", progress_kind: "amount" };

Deno.test("flag closed by default", () => {
  assertEquals(memberGoalsEnabled(() => undefined), false);
  assertEquals(memberGoalsEnabled(() => "1"), true);
});

Deno.test("weeklyProgress: buckets by week, ignores other goals and the running week", () => {
  const now = new Date(t0 + 15 * D); // أسبوعين كاملين + يوم
  assertEquals(weeklyProgress("g1", goal.created_at, [ev(1, 50), ev(3, 20), ev(8, 10), ev(14.5, 999), ev(2, 500, "other")], now), [70, 10]);
});

Deno.test("view: stalled goal -> proposal only, mentions consent; on-track -> none; non-amount -> null", () => {
  const now = new Date(t0 + 15 * D);
  const stalled = memberGoalView(goal, [ev(1, 10), ev(8, 5)], now)!;
  assertEquals(stalled.status.stalled, true);
  assert(stalled.proposal!.includes("ماتنفّذش من غير موافقته"));
  const ok = memberGoalView(goal, [ev(1, 130), ev(8, 130)], now)!;
  assertEquals(ok.proposal, null);
  assertEquals(memberGoalView({ ...goal, progress_kind: "tasks" }, [], now), null);
  assertEquals(memberGoalView({ ...goal, deadline_date: null }, [], now), null);
});
