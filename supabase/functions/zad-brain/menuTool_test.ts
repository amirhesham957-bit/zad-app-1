import { assert, assertEquals } from "jsr:@std/assert@1";
import { buildMenu, describeMenu, feedbackMap, parseMenuDishes } from "./menuTool.ts";
import { intentToolHints, scopeToolsForSpecialist } from "./specialists.ts";

const raw = [
  { name: "كبسة", cost: 120, tags: ["لحمة"] },
  { name: "فراخ", cost: 80, tags: ["فراخ"] },
  { name: "مكرونة", cost: 40, tags: ["نشويات"] },
  { name: "كشري", cost: 30 },
];

Deno.test("parse: good input, dedupes by name, trims", () => {
  const p = parseMenuDishes([...raw, { name: " كبسة ", cost: 5 }]);
  assert("dishes" in p);
  assertEquals(p.dishes.length, 4);
  assertEquals(p.dishes[3].tags, []);
});

Deno.test("parse: refuses empty, missing name, bad cost, too many", () => {
  for (const bad of [undefined, [], [{ name: "a", cost: 5 }], [{ name: "كبسة", cost: "x" }], [{ name: "كبسة", cost: -1 }]]) {
    const p = parseMenuDishes(bad);
    assert("error" in p, JSON.stringify(bad));
    assert(p.error.startsWith("مرفوض"));
  }
  assert("error" in parseMenuDishes(Array.from({ length: 41 }, (_, i) => ({ name: `طبق${i}`, cost: 1 }))));
});

Deno.test("taste from feedback: liked wins a tie, disliked is dropped and told", async () => {
  const p = parseMenuDishes(raw);
  assert("dishes" in p);
  const fb = feedbackMap([{ recipe_name: "فراخ", liked: true }, { recipe_name: "كبسة", liked: false }, { recipe_name: null, liked: true }]);
  const r = await buildMenu(p.dishes, fb, { days: 2, budget: 120 });
  assertEquals(r.dropped, ["كبسة"]);
  const picked = r.plan.days.map((id) => r.names.get(id!));
  assertEquals(picked.includes("فراخ"), true);
  assertEquals(picked.includes("كبسة"), false);
  assertEquals(r.plan.spent <= 120, true);
});

Deno.test("describe: every number comes from the plan; infeasible is flagged", async () => {
  const p = parseMenuDishes(raw);
  assert("dishes" in p);
  const r = await buildMenu(p.dishes, feedbackMap([]), { days: 5, budget: 100 });
  const costs = new Map([...r.names].map(([id, n]) => [id, p.dishes.find((d) => d.name === n)!.cost]));
  const text = describeMenu(r, costs, "جنيه");
  assert(text.includes("ميزانية المنيو: 100 جنيه لـ5 أيام"));
  assert(text.includes("مفيش طبق يدخل الميزانية"));
  assert(text.includes("مش مكفية"));
});

Deno.test("describe: a full menu shows the total and what is left", async () => {
  const p = parseMenuDishes(raw);
  assert("dishes" in p);
  const r = await buildMenu(p.dishes, feedbackMap([]), { days: 3, budget: 300 });
  const costs = new Map([...r.names].map(([id, n]) => [id, p.dishes.find((d) => d.name === n)!.cost]));
  const text = describeMenu(r, costs, "جنيه");
  assert(r.plan.feasible);
  assert(text.includes(`الإجمالي: ${r.plan.spent} جنيه`));
});

Deno.test("«منيو الأسبوع» reaches plan_menu; the pantry specialist carries it", () => {
  assertEquals(intentToolHints("عاوز منيو الأسبوع بميزانية ٤٠٠ جنيه").includes("plan_menu"), true);
  assertEquals(intentToolHints("جدول اكل الاسبوع بـ٣٠٠").includes("plan_menu"), true);
  assertEquals(intentToolHints("صباح الخير").includes("plan_menu"), false);
  const tools = scopeToolsForSpecialist([{ name: "plan_menu" } as never, { name: "log_transaction" } as never], "pantry", null, []);
  assertEquals(tools.some((t: { name: string }) => t.name === "plan_menu"), true);
  assertEquals(tools.some((t: { name: string }) => t.name === "log_transaction"), false);
});
