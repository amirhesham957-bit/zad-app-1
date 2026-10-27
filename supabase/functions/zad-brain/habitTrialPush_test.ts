import { assert, assertEquals } from "jsr:@std/assert@1";
import { habitTrialPush } from "./habitTrialPush.ts";

const trial = {
  id: "11111111-2222-3333-4444-555555555555", kind: "waste_less", category: "الهالك", currency: "EGP",
  status: "proposed", baseline_weekly: "1.50", result_weekly: null,
};

Deno.test("habit trial push (5.4): data-only fields name the trial and its stage, and the lines come from the row", () => {
  const p = habitTrialPush(trial, "لاحظت إن فيه حاجات بتترمي.")!;
  assertEquals(p.data, { kind: "habit_trial", trial_id: trial.id, stage: "proposed", route: "home" });
  assert(p.body.startsWith("لاحظت إن فيه حاجات بتترمي."));
  assert(p.body.includes("١٫٥ حاجة اترمت") && !p.body.includes("EGP"), "a count, not money");

  const result = habitTrialPush({ ...trial, status: "measured", result_weekly: 0.5 }, "النتيجة")!;
  assertEquals(result.data.stage, "measured");
  assert(result.body.includes("قبل التجربة ١٫٥ حاجة اترمت") && result.body.includes("أثناءها ٠٫٥ حاجة اترمت"));
});

Deno.test("habit trial push (5.4): a trial no longer waiting gets the ordinary notification", () => {
  assertEquals(habitTrialPush({ ...trial, status: "active" }, "x"), null);
  assertEquals(habitTrialPush({ ...trial, status: "measured" }, "x"), null);
  assertEquals(habitTrialPush({ ...trial, kind: "nope" }, "x"), null);
});
