import { assert, assertEquals } from "jsr:@std/assert@1";
import { FOOD_MIN_ITEMS, foodGroups, foodPatternInvite, foodPatternNote } from "./foodPattern.ts";

const NOW = Date.parse("2026-11-08T12:00:00Z");
const at = (days: number) => new Date(NOW - days * 86_400_000).toISOString();
const rows = (names: string[], days = 3) => names.map((name) => ({ name, at: at(days) }));
const staples = ["رز", "مكرونة", "زيت", "سكر", "شاي", "لبن", "جبنة", "عيش"];

Deno.test("too little to read says nothing", () => {
  assertEquals(foodPatternNote(rows(staples.slice(0, FOOD_MIN_ITEMS - 1)), NOW), null);
  assertEquals(foodPatternInvite(rows(["صابون", "مناديل"]), NOW), null);
});

Deno.test("the first real gap is what gets said, with the limits of the data", () => {
  const n = foodPatternNote(rows(staples), NOW)!;
  assertEquals(n.key, "food:veg");
  assert(n.question.includes("المشتريات المتسجلة"));
  assert(n.question.includes("الدكتور"));
  assertEquals(foodPatternNote(rows([...staples, "طماطم"]), NOW)?.key, "food:fruit");
  assertEquals(foodPatternNote(rows([...staples, "طماطم", "تفاح"]), NOW)?.key, "food:protein");
  assertEquals(foodPatternNote(rows([...staples, "طماطم", "تفاح", "بيض"]), NOW), null);
});

Deno.test("old purchases and repeats do not count", () => {
  assertEquals(foodGroups(rows(["طماطم"], 40), NOW).counts.veg, 0);
  assertEquals(foodGroups([...rows(["رز"]), ...rows(["رز"])], NOW).total, 1);
});

Deno.test("never a diagnosis and never about one person", () => {
  for (const names of [staples, [...staples, "طماطم"], [...staples, "طماطم", "تفاح"]]) {
    const q = foodPatternNote(rows(names), NOW)!.question;
    for (const word of ["فيتامين", "أنيميا", "نقص", "مرض", "حامل", "مراتك", "ابنك"]) assert(!q.includes(word), `${word} in ${q}`);
  }
});
