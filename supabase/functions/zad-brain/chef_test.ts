import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { formatChefResult, pantryForChef } from "./chef.ts";
import { APP_COMMAND_SCREENS, validateTool, freshContext } from "./validators.ts";
import { scopeToolsForSpecialist } from "./specialists.ts";

Deno.test("pantryForChef: Flutter's shape, stocked items only", () => {
  assertEquals(
    pantryForChef([
      { name: " رز ", qty: 2, unit: "كجم" },
      { name: "لبن", qty: 0 },
      { name: "", qty: 3 },
      { name: "بيض", qty: 12 },
    ]),
    "رز (2), بيض (12)",
  );
  assertEquals(pantryForChef(null), "");
  assertEquals(pantryForChef([]), "");
});

Deno.test("formatChefResult: the chef's own recipes, complete ones marked", () => {
  const out = formatChefResult({
    text: "عندك رز وبيض — ينفع حاجات حلوة",
    recipes: [
      { recipe_name: "أرز بالبيض", prep_time_minutes: 20, cost_estimate: 0, missing_ingredients_to_buy: [], from_inventory: true },
      { recipe_name: "كشري", prep_time_minutes: 45.4, cost_estimate: 60, missing_ingredients_to_buy: ["عدس", " مكرونة "] },
    ],
  }, "ج.م");
  assertStringIncludes(out, "شيف زاد: عندك رز وبيض");
  assertStringIncludes(out, "1. أرز بالبيض — مكتملة من المخزون · 20 دقيقة");
  assertStringIncludes(out, "2. كشري — ناقصها: عدس، مكرونة · 45 دقيقة · حوالي 60 ج.م");
  assertStringIncludes(out, "اعرض من دول بس");
  assertStringIncludes(out, "screen=recipes");
});

Deno.test("formatChefResult: no recipes is said plainly, never invented", () => {
  assertStringIncludes(formatChefResult({ text: "المخزون مايكفيش", recipes: [] }), "ماتخترعش");
  assertStringIncludes(formatChefResult(null), "مارجّعش وصفات");
});

Deno.test("formatChefResult: at most six", () => {
  const recipes = Array.from({ length: 9 }, (_, i) => ({ recipe_name: `وصفة ${i}`, missing_ingredients_to_buy: [] }));
  const out = formatChefResult({ recipes });
  assertStringIncludes(out, "6. وصفة 5");
  assertEquals(out.includes("7. "), false);
});

Deno.test("suggest_recipes: once per turn", async () => {
  const ctx = freshContext("u");
  assertEquals((await validateTool("suggest_recipes", {}, {}, ctx)).ok, true);
  ctx.counts["suggest_recipes"] = 1;
  assertEquals((await validateTool("suggest_recipes", {}, {}, ctx)).ok, false);
});

Deno.test("app_command can open the chef, prices, goals and nearby", async () => {
  for (const screen of ["recipes", "prices", "goals", "nearby"]) {
    assertEquals((APP_COMMAND_SCREENS as readonly string[]).includes(screen), true, screen);
    const v = await validateTool("app_command", { screen, action: "open" }, {}, freshContext("u"));
    assertEquals(v.ok, true, screen);
  }
});

Deno.test("the pantry specialist gets the chef", () => {
  const tools = [{ name: "suggest_recipes" }, { name: "add_debt" }];
  assertEquals(scopeToolsForSpecialist(tools, "pantry").map((t) => t.name), ["suggest_recipes"]);
});
