// طلب كتابة صريح والوكيل ماندهاش ⇒ محاولة إجبار (forcedIntent.ts). الحالات من التقييم حرفياً.
import { assertEquals } from "jsr:@std/assert@1";
import { forcedIntentTool, wantsForcedReminder } from "./forcedIntent.ts";
import { intentToolHints } from "./specialists.ts";

Deno.test("the eval's failed reminders all get the forced retry", () => {
  for (const m of [
    "فكرني بكرة الساعة 9 الصبح اكلم الدكتور",
    "ذكرني باچر الساعة ٨ اروح المدرسة",
    "عندي ميعاد مع المحامي يوم الخميس الساعة 4",
    "ذكرني بكرة الساعة ١٠ الصباح اراجع المستشفى",
    "فكرني بعد ساعتين اطفي الفرن",
    "remind me tomorrow at 7pm to call mom",
  ]) assertEquals(wantsForcedReminder(m), true, m);
});

Deno.test("never a question, an edit, a cancel, or a reminder with no time", () => {
  for (const m of [
    "امتى ميعاد الدكتور؟",
    "عندي ايه بكرة",
    "الغي تذكير الدكتور بكرة",
    "اجل ميعاد المحامي للخميس الساعة 5",
    "فكرني اشتري عيش",
    "صرفت 50 جنيه قهوة",
    "سجلي جرعة الدوا الساعة ٨",
  ]) assertEquals(wantsForcedReminder(m), false, m);
});

Deno.test("a medicine or a list item the agent claimed to add is forced through its own tool (eval 2/11)", () => {
  const pick = (m: string) => forcedIntentTool(m, intentToolHints(m));
  assertEquals(pick("ضيف شراب كحة لبنتي في الصيدلية"), "add_pharmacy_item");
  assertEquals(pick("زود عيش ع اللسته"), "add_shopping_item");
  assertEquals(pick("فكرني بكرة الساعة 9 الصبح اكلم الدكتور"), "add_appointment");
  for (const m of ["امسح البنادول من الصيدلية", "في ايه في اللسته؟", "صرفت 50 جنيه قهوة", "الزيت خلص من البيت"]) {
    assertEquals(pick(m), null, m);
  }
});
