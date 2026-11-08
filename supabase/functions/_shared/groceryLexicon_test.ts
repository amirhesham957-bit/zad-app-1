import { assertEquals } from "jsr:@std/assert@1";
import { isGroceryTerm } from "./groceryLexicon.ts";

Deno.test("each market's word for the groceries is one word for all of them", () => {
  for (const t of ["المقاضي", "مقاضي البيت", "خزين البيت", "الخزين", "طلبات البيت", "أغراض البيت", "السوبرماركت", "البقالة"]) {
    assertEquals(isGroceryTerm(t), true, t);
  }
});

Deno.test("an item, or the app called Talabat, is not", () => {
  for (const t of ["طلبات", "زيت", "زيت عباد الشمس", "مقاضي زيت", "", "   "]) {
    assertEquals(isGroceryTerm(t), false, t);
  }
  assertEquals(isGroceryTerm(null), false);
});
