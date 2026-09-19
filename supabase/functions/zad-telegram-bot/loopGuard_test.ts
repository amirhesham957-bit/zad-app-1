// الحلقة اللانهائية: كل حالة هنا اتشافت في الشات الحقيقي قبل ما تتقفل (٢٠٢٦-٠٩-١٩).
//
// البلاغ كان «البوت بيقرا رسايل نفسه ويرد عليها باستمرار»، وطلع سببين مختلفين بينتجوا
// نفس المنظر: راسل مش آدمي، وإعادة تسليم نفس التحديث من تليجرام. الفلتر ده بيقفل الأول؛
// التاني بيتقفل بـclaimUpdate في index.ts (بيلمس الداتابيز فمش هنا).

import { assert, assertEquals } from "jsr:@std/assert@1";
import { isHumanUpdate, parseDoseCallback, doseKeyboard, DOSE_MOMENTS } from "./telegram.ts";

Deno.test("رسالة من بني آدم بتعدّي", () => {
  assert(isHumanUpdate({ update_id: 1, message: { from: { is_bot: false } } }));
});

Deno.test("رسالة من بوت بتتسقط — ده نص الحلقة", () => {
  assertEquals(isHumanUpdate({ update_id: 2, message: { from: { is_bot: true } } }), false);
});

Deno.test("رسالة متبعوتة عن طريق بوت تاني بتتسقط", () => {
  assertEquals(isHumanUpdate({ update_id: 3, message: { from: { is_bot: false }, via_bot: { id: 9 } } }), false);
});

Deno.test("بوست قناة أو رسالة راسلها قناة مش شخص بتتسقط", () => {
  assertEquals(isHumanUpdate({ update_id: 4, channel_post: { text: "x" } }), false);
  assertEquals(isHumanUpdate({ update_id: 5, message: { from: { is_bot: false }, sender_chat: { id: -100 } } }), false);
});

Deno.test("تعديل رسالة قديمة مش رسالة جديدة — ماتتعملش عليها لفة وكيل", () => {
  assertEquals(isHumanUpdate({ update_id: 6, edited_message: { from: { is_bot: false } } }), false);
});

Deno.test("ضغطة زر من بني آدم بتعدّي، ومن بوت لأ", () => {
  assert(isHumanUpdate({ update_id: 7, callback_query: { from: { is_bot: false } } }));
  assertEquals(isHumanUpdate({ update_id: 8, callback_query: { from: { is_bot: true } } }), false);
});

Deno.test("جسم فاضي أو نوع تحديث مالوش handler بيتسقط", () => {
  assertEquals(isHumanUpdate(null), false);
  assertEquals(isHumanUpdate({ update_id: 9 }), false);
  assertEquals(isHumanUpdate({ update_id: 10, my_chat_member: {} }), false);
});

// ── أزرار الجرعة ────────────────────────────────────────────────────────────
const UUID = "3f2a1c4e-9b8d-4e7a-a1b2-c3d4e5f60718";

Deno.test("زر الجرعة تحت سقف تليجرام (٦٤ بايت) لكل زر", () => {
  for (const row of doseKeyboard(UUID)) {
    for (const btn of row) {
      assert(new TextEncoder().encode(btn.callback_data!).length <= 64, btn.callback_data);
    }
  }
});

Deno.test("parseDoseCallback بيفرّق بين أخدتها وأجّلها", () => {
  assertEquals(parseDoseCallback(`dz:${UUID}:t`), { momentId: UUID, action: "taken" });
  assertEquals(parseDoseCallback(`dz:${UUID}:s`), { momentId: UUID, action: "snooze" });
});

Deno.test("parseDoseCallback بيرفض أي حاجة مش شكلها مظبوط", () => {
  assertEquals(parseDoseCallback(`dz:${UUID}:x`), null);
  assertEquals(parseDoseCallback(`dz:not-a-uuid:t`), null);
  assertEquals(parseDoseCallback(`ck:${UUID}:y`), null);
  assertEquals(parseDoseCallback(""), null);
});

Deno.test("كل لحظات الدوا بتاخد زرار — مش dose_due بس", () => {
  for (const m of ["dose_due", "dose_nudge", "dose_missed", "dose_missed_again"]) {
    assert(DOSE_MOMENTS.has(m), m);
  }
  assertEquals(DOSE_MOMENTS.has("appointment_soon"), false);
});
