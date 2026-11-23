// «ضيف لبن للقايمة» من غير موديل — صنف واحد بس، والباقي للموديل زي ما هو (م٤.١).
import { assertEquals } from "jsr:@std/assert@1";
import { parseFastPath } from "./fastPath.ts";

Deno.test("one plain item to the shopping list is parsed without a model", () => {
  assertEquals(parseFastPath("ضيف لبن للقايمة"), { kind: "shopping_add", item: "لبن" });
  assertEquals(parseFastPath("أضف عيش لقايمة التسوق"), { kind: "shopping_add", item: "عيش" });
  assertEquals(parseFastPath("حط زيت عباد الشمس في القايمة"), { kind: "shopping_add", item: "زيت عباد الشمس" });
  assertEquals(parseFastPath("ضيف رز للتسوق"), { kind: "shopping_add", item: "رز" });
});

Deno.test("quantity, unit, second item or anything ambiguous goes to the model", () => {
  for (const m of [
    "ضيف لبن ٢ للقايمة",            // quantity
    "ضيف كيلو سكر للقايمة",          // unit
    "ضيف لبن وعيش للقايمة",          // two items
    "ضيف لبن، عيش للقايمة",          // two items
    "ضيف لبن للقايمة بس مش دلوقتي",  // trailing clause
    "ضيف دوا للقايمة",               // pharmacy, not shopping
    "ضيف موعد الدكتور للقايمة",      // appointment
    "ضيف لبن للمخزن",                // pantry, not the list
    "ضيف ٥٠ جنيه للقايمة",           // money
    "ضيف لبن",                       // no destination
    "ضيف شوية حاجات حلوة كتير للقايمة", // too many words
    "ضيف لبن للقايمة؟",
  ]) {
    assertEquals(parseFastPath(m), null, m);
  }
});
