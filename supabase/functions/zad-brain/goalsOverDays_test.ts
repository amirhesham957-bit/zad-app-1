// ZAD_PLAN ١٠.٢(د): أهداف على أيام — الخطوة كل أسبوع، والتقدم بكلام العميل، والوحدة لازم تتقال.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { stepPerWeek } from "./goalPace.ts";
import { intentToolHints } from "./specialists.ts";
import { freshContext, MUTATING_TOOLS, validateTool } from "./validators.ts";

const NOW = new Date("2026-11-13T10:00:00Z");

Deno.test("«2000 before Ramadan» splits into what is left per week", () => {
  // ١٣/١١ ⇒ ١٨/٢: ١٣ أسبوع ونص ⇒ ١٤ أسبوع؛ ٢٠٠٠ ÷ ١٤ = ١٤٢٫٨ ⇒ ١٤٣ لفوق.
  assertEquals(stepPerWeek({ target_value: 2000, current_value: 0, deadline_date: "2027-02-18" }, NOW), 143);
  // اللي اتحط بيتشال من الباقي.
  assertEquals(stepPerWeek({ target_value: 2000, current_value: 600, deadline_date: "2027-02-18" }, NOW), 100);
  // آخر أسبوع: الباقي كله.
  assertEquals(stepPerWeek({ target_value: 400, current_value: 100, deadline_date: "2026-11-15" }, NOW), 300);
});

Deno.test("no step for a goal without a number or a date, a finished goal, or a passed deadline", () => {
  assertEquals(stepPerWeek({ target_value: null, current_value: 0, deadline_date: "2027-01-01" }, NOW), null);
  assertEquals(stepPerWeek({ target_value: 500, current_value: 0, deadline_date: null }, NOW), null);
  assertEquals(stepPerWeek({ target_value: 500, current_value: 500, deadline_date: "2027-01-01" }, NOW), null);
  assertEquals(stepPerWeek({ target_value: 500, current_value: 0, deadline_date: "2026-11-01" }, NOW), null);
});

Deno.test("a goal with a number has to say whether it is money or a count", async () => {
  const base = { title: "وفّر لرمضان", action: "add", target_value: 2000, deadline_date: "2027-02-18" };
  assertEquals((await validateTool("set_life_goal", base, {}, freshContext("u1"))).ok, false);
  assertEquals((await validateTool("set_life_goal", { ...base, unit: "money" }, {}, freshContext("u1"))).ok, true);
  assertEquals((await validateTool("set_life_goal", { ...base, unit: "count" }, {}, freshContext("u1"))).ok, true);
  // من غير رقم: مفيش وحدة تتقال، وزي ما كان.
  assertEquals((await validateTool("set_life_goal", { title: "أبطّل السكر", action: "add" }, {}, freshContext("u1"))).ok, true);
});

Deno.test("progress goes only to a money goal the customer has, with an amount he said", async () => {
  const snap = {
    life_goals: [
      { title: "رمضان", kind: "amount", target: 2000, done: 0 },
      { title: "ألتزم بميزانية الشهر", target: 12, done: 1 },
    ],
  };
  assertEquals((await validateTool("add_goal_progress", { goal_title: "رمضان", amount: 500 }, snap, freshContext("u1"))).ok, true);
  assertEquals((await validateTool("add_goal_progress", { goal_title: "رمضان", amount: -200 }, snap, freshContext("u1"))).ok, true);
  assertEquals((await validateTool("add_goal_progress", { goal_title: "رمضان", amount: 0 }, snap, freshContext("u1"))).ok, false);
  assertEquals((await validateTool("add_goal_progress", { goal_title: "المصيف", amount: 500 }, snap, freshContext("u1"))).ok, false);
  // هدف بيتعد بالمهام ماياخدش مبلغ.
  assertEquals((await validateTool("add_goal_progress", { goal_title: "ألتزم بميزانية الشهر", amount: 1 }, snap, freshContext("u1"))).ok, false);
  assert(MUTATING_TOOLS.includes("add_goal_progress"));
});

Deno.test("«I put 500 aside» brings the progress tool, and so does a bare number after «how much this week?»", () => {
  for (const msg of ["حطيت 500 للمصيف", "حوشت ٢٠٠ الأسبوع ده", "300 على جنب", "وفرت 150"]) {
    assert(intentToolHints(msg).includes("add_goal_progress"), msg);
  }
  assert(intentToolHints("٥٠٠", "حطيت كام الأسبوع ده لهدف رمضان؟").includes("add_goal_progress"));
  for (const msg of ["اشتريت عيش بـ20", "حطيت الأكل في التلاجة"]) {
    assertEquals(intentToolHints(msg).includes("add_goal_progress"), false, msg);
  }
});
