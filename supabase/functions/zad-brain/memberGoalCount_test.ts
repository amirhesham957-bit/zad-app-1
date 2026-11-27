import { assert, assertEquals } from "jsr:@std/assert@1";
import { extendedDeadline, isExplicitApproval, memberGoalView, taskEventsFor } from "./memberGoalWiring.ts";

const D = 86_400_000;
const t0 = Date.parse("2026-10-01T00:00:00Z");

Deno.test("count goals: progress comes from completed tasks, same status logic", () => {
  const now = new Date(t0 + 15 * D);
  const cg = { id: "g2", title: "تمارين", target_value: 20, deadline_date: "2026-11-26", created_at: "2026-10-01T00:00:00Z", progress_kind: "tasks" };
  const task = (day: number) => ({ goal_id: "g2", updated_at: new Date(t0 + day * D).toISOString() });
  const stalled = memberGoalView(cg, [], now, taskEventsFor("g2", [task(1), task(9), { ...task(2), goal_id: "other" }]))!;
  assertEquals([stalled.status.done, stalled.status.stalled], [2, true]);
  assert(stalled.proposal!.includes("apply_goal_adjustment"));
  const ok = memberGoalView(cg, [], now, taskEventsFor("g2", [1, 2, 3, 8, 9, 10].map(task)))!;
  assertEquals(ok.status.stalled, false);
  assertEquals(memberGoalView(cg, [], now), null); // من غير بيانات المهام مافيش حالة
});

Deno.test("approval is explicit, short and never negated", () => {
  for (const s of ["أيوه", "ايوه مد الميعاد", "موافق", "تمام نفّذ", "yes"]) assertEquals(isExplicitApproval(s), true, s);
  for (const s of ["لا", "لأ مش موافق", "", undefined, "ايوه بس بلاش دلوقتي", "عايز أعرف الأول إيه اللي هيحصل للهدف لو مديت الميعاد وايوه"]) {
    assertEquals(isExplicitApproval(s), false, String(s));
  }
});

Deno.test("extendedDeadline: created + weeks, server-computed", () => {
  assertEquals(extendedDeadline("2026-10-01T00:00:00Z", 10), "2026-12-10");
  assertEquals(extendedDeadline("bad", 10), null);
});
