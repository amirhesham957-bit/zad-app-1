// استهلاك صريح والموديل ماكتبش في المخزن ⇒ محاولة إجبار consume_item (forcedConsume.ts). الحالات من فحص ١٤/١١.
import { assertEquals } from "jsr:@std/assert@1";
import { shouldForceConsume, wantsForcedConsume } from "./forcedConsume.ts";

Deno.test("forcedConsume: consumption said plainly is forced", () => {
  for (const m of ["فتحنا علبة لبن", "فتحت علبة اللبن", "فتحنا علبة لبن جديدة النهارده", "شربنا ٣ مية", "طبخنا مكرونة", "أكلنا الجبنة"]) {
    assertEquals(wantsForcedConsume(m), true, m);
  }
});

Deno.test("forcedConsume: questions, eating out and other verbs are not", () => {
  for (const m of ["نطبخ ايه النهارده؟", "اكلت ايه امبارح", "هل اللبن المفتوح يبوظ", "اكلنا برا النهارده", "طلبنا اكل وأكلنا", "اشتريت لبن", "فتحوا المحل؟", ""]) {
    assertEquals(wantsForcedConsume(m), false, m);
  }
});

Deno.test("forcedConsume: not when the pantry was already written or a card is waiting", () => {
  assertEquals(shouldForceConsume("فتحنا علبة لبن", [], 0), true);
  assertEquals(shouldForceConsume("فتحنا علبة لبن", ["remember"], 0), true);
  assertEquals(shouldForceConsume("فتحنا علبة لبن", ["consume_item"], 0), false);
  assertEquals(shouldForceConsume("شربنا ٣ مية", ["update_inventory_qty"], 0), false);
  assertEquals(shouldForceConsume("فتحنا علبة لبن", [], 1), false);
});
