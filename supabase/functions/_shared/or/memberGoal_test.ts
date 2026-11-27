import { assert, assertEquals } from "jsr:@std/assert";
import { adjustStalledGoal, goalStatus } from "./memberGoal.ts";

Deno.test("goalStatus: ماشي كويس", () => {
  const s = goalStatus({ target: 1000, weeks: 10, weeklyProgress: [100, 120] });
  assertEquals([s.done, s.remaining, s.weeksLeft, s.stalled, s.met], [220, 780, 8, false, false]);
});

Deno.test("goalStatus: وقف بعد أسبوعين تحت النص", () => {
  assert(goalStatus({ target: 1000, weeks: 10, weeklyProgress: [100, 20, 10] }).stalled);
  assert(!goalStatus({ target: 1000, weeks: 10, weeklyProgress: [20, 100, 10] }).stalled);
  assert(!goalStatus({ target: 1000, weeks: 10, weeklyProgress: [10] }).stalled);
});

Deno.test("goalStatus: الهدف اتحقق مابيبقاش واقف", () => {
  const s = goalStatus({ target: 100, weeks: 4, weeklyProgress: [60, 0, 0, 50] });
  assert(s.met && !s.stalled);
});

Deno.test("adjust: مفيش تعديل لو ماشي", () => {
  assertEquals(adjustStalledGoal({ target: 1000, weeks: 10, weeklyProgress: [100, 100] }).kind, "none");
});

Deno.test("adjust: لو وقف بيمدّد المدة وبيخفّض الخطوة", () => {
  const g = { target: 1000, weeks: 10, weeklyProgress: [100, 20, 10] };
  const a = adjustStalledGoal(g);
  assertEquals(a.kind, "extend_deadline");
  assert(a.weeks > 10 && a.weeks <= 18);
  assert(a.stepPerWeek < goalStatus(g).stepPerWeek);
});

Deno.test("adjust: المدّ مايتعداش ٨ أسابيع", () => {
  const a = adjustStalledGoal({ target: 100000, weeks: 4, weeklyProgress: [1, 1] });
  assertEquals(a.weeks, 4 + 8);
});
