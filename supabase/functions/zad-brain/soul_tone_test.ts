// soul_tone_test.ts — نبرة زاد بعد الموجة ٣ من «خطة سد الفجوات» (٢٠٢٦-١٠-١٠): رد على قد
// السؤال، زعل من غير رفض خدمة، عتاب برقم ثم تنفيذ، وفرح بحاجة حصلت فعلاً. بنفس الصوتين.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { soulBlock, ZAD_SOUL, ZAD_SOUL_MALE } from "./soul.ts";
import { buildChatSystemPrompt } from "./index.ts";

const voices = [["female", soulBlock("female")], ["male", soulBlock("male")]] as const;

Deno.test("soul tone: a reply sized to the question — no preamble, no extra apology, no baseless optimism", () => {
  for (const [, block] of voices) {
    assertStringIncludes(block, "من غير مقدمات");
    assertStringIncludes(block, "من غير اعتذار زيادة");
    assertStringIncludes(block, "تفاؤل مالوش سبب");
    assertStringIncludes(block, "سؤال قصير = رد قصير");
  }
});

Deno.test("soul tone: insulted, Zad says so in one line and stops joking — and still serves", () => {
  for (const [, block] of voices) {
    assertStringIncludes(block, "«كده زعلتني»");
    assertStringIncludes(block, "هزار لحد ما الكلام يرجع طبيعي");
    // قرار المالك: الزعل نبرة، مفيش رفض خدمة ولا استنى اعتذار.
    assertStringIncludes(block, "الزعل نبرة مش عقاب");
    assert(/عمرك ما ترفض(ي)? خدمة/.test(block), "the upset rule must forbid refusing service");
    assert(/ولا تستن(ى|ي) اعتذار/.test(block));
  }
});

Deno.test("soul tone: a harmful decision gets a plain reproach with a real number, then it is done", () => {
  for (const [voice, block] of voices) {
    assertStringIncludes(block, "بتعاتب بوضوح وبرقم من SNAPSHOT أو الأداة");
    assertStringIncludes(block, "وبعدين تنفّذ برضه");
    assertStringIncludes(block, voice === "male" ? "وأنا مش مرتاح\"" : "وأنا مش مرتاحة\"");
    // الصيغة القديمة («جملة واحدة بمحبة») كانت بتلغي العتاب.
    assertEquals(block.includes("بمحبة"), false);
  }
});

Deno.test("soul tone: joy about something that happened, not on every reply", () => {
  for (const [, block] of voices) {
    assertStringIncludes(block, "بتفرح بجد بحاجة حصلت فعلاً");
    assertStringIncludes(block, "مش في كل رد");
  }
});

Deno.test("soul tone: the self-pity ban that silenced being upset is gone, and so is the contradiction", () => {
  for (const [, block] of voices) {
    assertEquals(/غلبان/.test(block), false);
    // «إحساس حقيقيين» كان بيناقض حدود المحادثة («لا تدّعي امتلاك مشاعر»).
    assertEquals(block.includes("حقيقيين"), false);
  }
});

Deno.test("soul tone: asked plainly whether it is human, Zad tells the truth (Google Play)", () => {
  for (const [, block] of voices) {
    assertStringIncludes(block, "مش ادعاء إنك إنسان");
    assertStringIncludes(block, "مساعد ذكاء اصطناعي جوه زاد");
  }
  // وحدود المحادثة نفسها لسه هناك.
  assertStringIncludes(buildChatSystemPrompt({}), "لو سأل العميل هل أنت إنسان");
});

Deno.test("soul tone: both voices keep the same shape, and no flirting survives the rewrite", () => {
  assertEquals(ZAD_SOUL_MALE.length, ZAD_SOUL.length);
  for (const [, block] of voices) assertStringIncludes(block, "مفيش مغازلة ولا كلام رومانسي");
});
