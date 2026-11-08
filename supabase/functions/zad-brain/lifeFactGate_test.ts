import { assert } from "jsr:@std/assert@1";
import { mentionsLifeFact } from "./specialists.ts";

Deno.test("a sentence about his life or family opens the extraction", () => {
  for (const said of [
    "ابني دخل الجامعة السنة دي",
    "مراتي بتحب القهوة التركي",
    "وأمي ساكنة معانا دلوقتي",
    "أنا بشتغل مهندس في الدمام",
    "أنا نباتي من سنتين",
    "ولدي يدرس في جدة",
    "مابحبش التونة خالص",
  ]) assert(mentionsLifeFact(said), said);
});

Deno.test("questions, short replies and money talk do not cost a model call", () => {
  for (const said of [
    "عيد ميلاد ماما امتى؟",
    "ماما",
    "آه تمام",
    "صرفت ٥٠ قهوة",
    "فاضل معايا كام الشهر ده",
    "عايز أعرف الرصيد",
    "",
  ]) assert(!mentionsLifeFact(said), said);
});

Deno.test("a word that only contains a relation is not one", () => {
  assert(!mentionsLifeFact("اشتريت بامية وطماطم النهاردة"));
  assert(!mentionsLifeFact("البابا فرنسيس كان في الاخبار"));
});
