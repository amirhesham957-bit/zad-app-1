import { assertEquals } from "jsr:@std/assert@1";
import { isJoke, JOKE_BLOCKED_TOOLS, JOKE_RULE, jokeVerdict } from "./jokeFilter.ts";

Deno.test("تصريح بالهزار = هزار", () => {
  for (const m of ["بهزر معاك يا زاد", "ده هزار طبعاً", "انا بمزح والله", "كدبة بيضا", "ببالغ شوية", "أنا بهزّر"]) {
    assertEquals(jokeVerdict(m), { joke: true, kind: "explicit" }, m);
  }
});

Deno.test("مبالغة صريحة = هزار", () => {
  for (const m of ["اشتريت السوق كله", "صرفت الدنيا امبارح", "دفعت مليار جنيه في القهوة", "اشتريت الدنيا كلها"]) {
    assertEquals(isJoke(m), true, m);
  }
});

Deno.test("ضحكة + رقم خيالي = هزار، وضحكة لوحدها لأ", () => {
  assertEquals(jokeVerdict("اشتريت عربية بمليون جنيه هههه").kind, "laugh_absurd");
  assertEquals(jokeVerdict("صرفت 500000000 على الشاي 😂").kind, "laugh_absurd");
  assertEquals(isJoke("سجل ٥٠ قهوة 😂"), false);
  assertEquals(isJoke("هههههه"), false);
});

Deno.test("الجد مايتفلترش (لا إيجابية كاذبة)", () => {
  for (const m of [
    "سجل ٥٠ قهوة", "اشتريت ٣ علب لبن بـ ١٢٠", "دفعت إيجار ٥٠٠٠", "صرفت ٨٠٠ في السوبر ماركت",
    "اشتريت عربية بمليون جنيه", "فاضل كام", "ضيف ملوخية للمخزن", "",
  ]) assertEquals(isJoke(m), false, m);
});

Deno.test("كل الأدوات الحساسة محظورة في الهزار، والقاعدة مصرية قصيرة", () => {
  for (const t of ["log_transaction", "add_inventory_item", "consume_item", "add_shopping_item", "remember", "set_item_preference"]) {
    assertEquals(JOKE_BLOCKED_TOOLS.has(t), true, t);
  }
  assertEquals(JOKE_RULE.includes("ممنوع أي أداة كتابة"), true);
  assertEquals(JOKE_RULE.length < 330, true);
});
