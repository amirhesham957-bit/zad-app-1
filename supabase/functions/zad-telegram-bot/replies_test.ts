// الرد بالكلام على البوت (٢٠٢٦-٠٩-٢٥). البلاغ: «لما أقول لا مش بيقراها، بيقرا الموافقة بس»،
// و«لما بدوس مخدتش الدوا او الرقم ده غلط مش بيقراها».
//
// أول اختبار هنا هو السبب الجذري نفسه: الـregex القديم بـ`\b` كان بيرجّع false لكل رد عربي.

import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  doseKeyboard, parseAmountWrongCallback, parseDoseCallback, parseDoseReply, parseYesNoReply,
  transactionProposalKeyboard,
} from "./telegram.ts";

const UUID = "3f2a1c4e-9b8d-4e7a-a1b2-c3d4e5f60718";

Deno.test("السبب الجذري: \\b مابيشوفش حد بعد الحروف العربي", () => {
  const old = /^\s*(لا|أيوه)\b/i;
  assertEquals(old.test("لا"), false);
  assertEquals(old.test("أيوه"), false);
});

Deno.test("الردود العربي القصيرة بتتفهم", () => {
  for (const s of ["لا", "لأ", "لا شكرا", "لأ مش دي", "الغي", "رفض", "غلط", "no"]) {
    assertEquals(parseYesNoReply(s), "no", s);
  }
  for (const s of ["أيوه", "ايوه اكد", "تمام", "اه", "آه", "ماشي", "موافق", "أكيد!", "ok", "تمام.", "صح"]) {
    assertEquals(parseYesNoReply(s), "yes", s);
  }
});

Deno.test("الكلام اللي فيه معلومة مش أيوه/لا — يروح للموديل", () => {
  for (const s of [
    "تمام بس المبلغ 150 مش 200 خالص",
    "مش فاهم",
    "أي حاجة",
    "ايه ده",
    "لازم أدفع الإيجار",
    "لاعب",
    "تمامك",
    "",
  ]) {
    assertEquals(parseYesNoReply(s), null, s);
  }
});

Deno.test("رد صريح عن الجرعة: أخدتها / مخدتهاش", () => {
  for (const s of ["أخدته", "خدته", "اخدتها", "خدت الدوا", "خدتو الحمدلله", "أخدت"]) {
    assertEquals(parseDoseReply(s), "taken", s);
  }
  for (const s of ["مخدتش", "ماخدتش", "مخدتهاش", "ما خدتش الدوا", "مأخدتش", "نسيت", "نسيته", "مش هاخده"]) {
    assertEquals(parseDoseReply(s), "skipped", s);
  }
  for (const s of ["خد بالك", "اخدت فلوس من البنك امبارح وبعدين رحت السوق واشتريت حاجات كتير"]) {
    assertEquals(parseDoseReply(s), null, s);
  }
});

Deno.test("زرار «مخدتهاش» موجود ومفهوم، وكل الأزرار تحت ٦٤ بايت", () => {
  const all = doseKeyboard(UUID).flat();
  assert(all.some((b) => b.callback_data === `dz:${UUID}:k`));
  for (const b of all) assert(new TextEncoder().encode(b.callback_data!).length <= 64);
  assertEquals(parseDoseCallback(`dz:${UUID}:k`), { momentId: UUID, action: "skipped" });
});

Deno.test("زرار «المبلغ غلط» على الاقتراح في الحالتين", () => {
  for (const status of ["awaiting_confirmation", "needs_classification"] as const) {
    const all = transactionProposalKeyboard(UUID, status, "expense").flat();
    assert(all.some((b) => b.callback_data === `pw:${UUID}`), status);
  }
  assertEquals(parseAmountWrongCallback(`pw:${UUID}`), UUID);
  assertEquals(parseAmountWrongCallback(`pr:${UUID}`), null);
  assertEquals(parseAmountWrongCallback(`pw:nope`), null);
});
