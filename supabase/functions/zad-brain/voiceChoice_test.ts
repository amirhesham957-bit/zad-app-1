// صوت زاد اختيار العميل في «ملفي» (20261003130000): نفس زاد ونفس القواعد، وكلامه عن نفسه بصيغة الصوت
// اللي اتختار. ومفيش مغازلة بأي صوت (قرار المالك ٢٠٢٦-١٠-٠٣).
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { soulBlock, ZAD_SOUL, ZAD_SOUL_MALE } from "./soul.ts";
import { voiceModeInstruction } from "./persona.ts";
import { buildMomentPrompt } from "./voiceMoments.ts";
import { customerCard } from "../_shared/customerProfile.ts";
import { buildChatSystemPrompt } from "./index.ts";

Deno.test("soul: a boy's voice is the same Zad, speaking of himself as a boy", () => {
  const boy = soulBlock("male");
  assertStringIncludes(boy, "أنت ولد ذكي");
  assertStringIncludes(boy, "بصيغة المذكر");
  assertEquals(boy.includes("أنت بنت ذكية"), false);
  assertStringIncludes(soulBlock(), "أنت بنت ذكية");
  assertStringIncludes(soulBlock("female"), "أنت بنت ذكية");
  assertStringIncludes(soulBlock(null), "أنت بنت ذكية");
  // نفس عدد الفقرات ونفس القواعد اللي مالهاش علاقة بالصوت.
  assertEquals(ZAD_SOUL_MALE.length, ZAD_SOUL.length);
  assertEquals(ZAD_SOUL_MALE[0], ZAD_SOUL[0]);
  assertEquals(ZAD_SOUL_MALE.at(-1), ZAD_SOUL.at(-1));
});

Deno.test("soul: no flirting, whatever the voice and whoever starts it", () => {
  for (const block of [soulBlock("female"), soulBlock("male")]) {
    assertStringIncludes(block, "مفيش مغازلة ولا كلام رومانسي");
    assertStringIncludes(block, "حتى لو العميل بدأ");
  }
});

Deno.test("voice mode: the call and the chat follow the chosen voice", () => {
  assertStringIncludes(voiceModeInstruction(true, "male"), "أنت ولد");
  assertStringIncludes(voiceModeInstruction(true, "male"), "رجالي");
  assertEquals(voiceModeInstruction(true, "male").includes("أنثوي"), false);
  assertStringIncludes(voiceModeInstruction(false, "male"), "بصيغة المذكر");
  assertStringIncludes(voiceModeInstruction(true), "بنت حرة");
});

Deno.test("moments: a boy's voice writes the moment as a friend, with a boy's delivery", () => {
  const boy = buildMomentPrompt({ moment: "good_night", facts: {} }, "EG", "أمير", { gender: "male", zad_voice: "male" });
  assertStringIncludes(boy.system, "صاحبه المقرب");
  assertStringIncludes(boy.system, "older brother");
  assertEquals(boy.system.includes("صاحبته المقربة"), false);
  const girl = buildMomentPrompt({ moment: "good_night", facts: {} }, "EG", "أمير", { gender: "male" });
  assertStringIncludes(girl.system, "صاحبته المقربة");
});

Deno.test("customer card: the voice defaults to a girl's and is never «missing»", () => {
  assertEquals(customerCard(null, {}).zad_voice, "female");
  assertEquals(customerCard({ zad_voice: "male" }, {}).zad_voice, "male");
  assertEquals(customerCard({ zad_voice: "robot" }, {}).zad_voice, "female");
  assert(!(customerCard(null, {}).missing_important as string[]).includes("zad_voice"));
});

Deno.test("chat: asked to change its voice, Zad points to «ملفي» instead of claiming it did", () => {
  const prompt = buildChatSystemPrompt({ customer: customerCard(null, {}) });
  assertStringIncludes(prompt, "صوتك (customer.zad_voice)");
  assertStringIncludes(prompt, "ماتقولش إنك غيّرته");
});
