// «فكّرني كمان دقيقتين أشرب مية» من غير موديل — والباقي للموديل زي ما هو.
import { assertEquals } from "jsr:@std/assert@1";
import { parseFastPath } from "./fastPath.ts";

Deno.test("a relative reminder is arithmetic: parsed without a model", () => {
  assertEquals(parseFastPath("فكّرني كمان دقيقتين أشرب مية"), { kind: "relative_reminder", minutes: 2, title: "أشرب مية" });
  assertEquals(parseFastPath("فكريني بعد ١٠ دقايق أطفي الفرن"), { kind: "relative_reminder", minutes: 10, title: "أطفي الفرن" });
  assertEquals(parseFastPath("ذكرني كمان نص ساعة إني أكلم ماما"), { kind: "relative_reminder", minutes: 30, title: "أكلم ماما" });
  assertEquals(parseFastPath("نبهني بعد ساعتين بالغسيل"), { kind: "relative_reminder", minutes: 120, title: "الغسيل" });
  assertEquals(parseFastPath("فكرني كمان 3 ساعات أخد الدوا"), { kind: "relative_reminder", minutes: 180, title: "أخد الدوا" });
});

Deno.test("anything with a second time, a repetition or a second request goes to the model", () => {
  for (const m of [
    "فكرني كمان ساعة أشرب مية وكل ساعة بعدها",     // repetition
    "فكرني كمان ساعة أكلم ماما الساعة ٥",           // second time
    "فكرني كمان ساعة أكلم ماما و أطفي الفرن",       // two requests
    "فكرني بكرة الساعة ٥ أروح البنك",              // absolute time
    "فكرني كمان شوية أشرب مية",                    // no duration
    "فكرني كمان ١٥ ساعة أنام",                     // > 12 hours
    "كمان دقيقتين أشرب مية",                       // no verb
    "فكرني كمان دقيقتين",                          // nothing to remember
    "فكرني كمان دقيقتين ؟",
  ]) {
    assertEquals(parseFastPath(m), null, m);
  }
});

Deno.test("whole words: «أكلم» is not «كل»", () => {
  assertEquals(parseFastPath("فكرني كمان ساعة أكلم خالد")?.kind, "relative_reminder");
});
