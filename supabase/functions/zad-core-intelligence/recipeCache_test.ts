import { assert, assertEquals } from "jsr:@std/assert@1";
import { mealSuggestionsCacheKey, mealSuggestionsCachePattern } from "./recipeCache.ts";

// Postgres LIKE, for the two wildcards the pattern uses.
function like(value: string, pattern: string): boolean {
  const escaped = pattern.replace(/[.*+?^${}()|[\]\\]/g, "\\$&").replace(/%/g, ".*").replace(/_/g, ".");
  return new RegExp(`^${escaped}$`, "s").test(value);
}

const user = "3f2a9c1e-1111-2222-3333-444455556666";

Deno.test("rate_recipe's delete matches every key meal_suggestions writes for that user", () => {
  for (const brokeMode of [false, true]) {
    const key = mealSuggestionsCacheKey({
      userId: user, dialect: "eg", person: "f", brokeMode, items: "لبن (2), أرز (1)",
    });
    assert(like(key, mealSuggestionsCachePattern(user)), key);
  }
});

Deno.test("and no other user's", () => {
  const key = mealSuggestionsCacheKey({
    userId: "aaaaaaaa-1111-2222-3333-444455556666", dialect: "eg", person: "f", brokeMode: false, items: "",
  });
  assertEquals(like(key, mealSuggestionsCachePattern(user)), false);
});

Deno.test("the key the pattern was written against: the old one did not match", () => {
  const key = mealSuggestionsCacheKey({ userId: user, dialect: "eg", person: "f", brokeMode: false, items: "x" });
  assertEquals(like(key, `meal_suggestions:${user}:%`), false);
});
