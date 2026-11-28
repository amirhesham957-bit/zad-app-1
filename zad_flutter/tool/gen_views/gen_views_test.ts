import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";
import { checkActions, parseViews, render } from "./gen_views.ts";

const SQL = await Deno.readTextFile(
  new URL("../../../supabase/migrations/20261127140000_view_rpcs.sql", import.meta.url),
);
const ALLOWED: string[] = JSON.parse(
  await Deno.readTextFile(new URL("allowed_actions.json", import.meta.url)),
).actions;

Deno.test("parses the 4 views with numbers and sources", () => {
  const v = Object.fromEntries(parseViews(SQL).map((s) => [s.name, s]));
  assertEquals(v.money.numbers.length, 10);
  assertEquals(v.money.numbers[0], { key: "balance", source: "zad_budget_state.balance" });
  assertEquals(v.home.numbers.find((n) => n.key === "available")?.source, "zad_budget_state.available");
  assert(v.family.numbers.some((n) => n.key === "spent_30d"));
  assert(v.money.hasThreat && v.home.hasThreat && !v.house.hasThreat);
});

Deno.test("all migration actions are allowed", () => {
  assertEquals(checkActions(parseViews(SQL), ALLOWED), []);
});

Deno.test("fails on a renamed/temporary action id", () => {
  const sql = SQL.replace("'add_expense'", "'tmp_add_expense'");
  assertEquals(checkActions(parseViews(sql), ALLOWED), ["money: tmp_add_expense"]);
});

Deno.test("output changes when a column or action changes", () => {
  const base = render(parseViews(SQL), ALLOWED);
  const col = render(parseViews(SQL.replace("'spent', public", "'spent2', public")), ALLOWED);
  assert(base !== col && col.includes("spent2"));
  const act = render(parseViews(SQL), [...ALLOWED, "extra"]);
  assert(base !== act);
});

Deno.test("missing function throws", () => {
  assertThrows(() => parseViews(SQL.replaceAll("zad_view_house", "zad_view_hause")));
});
