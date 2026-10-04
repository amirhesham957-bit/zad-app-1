import { assertEquals, assertMatch } from "jsr:@std/assert@1";
import { conversationProfile, voiceModeInstruction } from "./persona.ts";

Deno.test("persona follows the account country, the customer's own choice and how they write", () => {
  assertEquals(conversationProfile("EG").locale, "ar-EG");
  assertEquals(conversationProfile("SA").locale, "ar-SA");
  assertEquals(conversationProfile("تركيا").locale, "tr-TR");
  // مصري ساكن في السعودية واختار مصري في ملفه
  assertEquals(conversationProfile("SA", { preferred: "EG" }).dialect, "EG");
  // حساب من غير بلد بس بيكتب سعودي واضح
  assertEquals(conversationProfile(null, { text: "ابغى اعرف وش صرفت الحين" }).dialect, "SA");
  // التعليمة نفسها مكتوبة باللهجة، مش بالفصحى
  assertMatch(conversationProfile("EG").instruction, /اتكلم مصري/);
});

Deno.test("voice mode asks for speech-sized turns", () => {
  assertMatch(voiceModeInstruction(true), /جملك قصيرة/);
  assertMatch(voiceModeInstruction(true), /بنت حرة/);
  assertMatch(voiceModeInstruction(false), /محادثة مكتوبة/);
});

Deno.test("voice mode treats an odd transcript as mishearing, not as a joke (2026-09-30)", () => {
  const voice = voiceModeInstruction(true);
  assertMatch(voice, /تفريغ صوت/);
  assertMatch(voice, /ماسمعتيهاش كويس/);
  assertMatch(voice, /بالافتراضي/);
  // Typed text is what the customer wrote: no such rule.
  assertEquals(/تفريغ صوت/.test(voiceModeInstruction(false)), false);
});

Deno.test("child tone: only a child's account gets it, and it keeps money talk and strangers out", async () => {
  const { childToneBlock } = await import("./persona.ts");
  const child = { family: { mine: { role: "child", alias: "سارة", balance: 40, savings_goal: 100 } } };
  const parent = { family: { mine: { role: "admin", alias: "بابا" } } };
  assertEquals(childToneBlock(parent), "");
  assertEquals(childToneBlock({}), "");
  assertEquals(childToneBlock(null), "");
  const block = childToneBlock(child);
  assertMatch(block, /بتكلم طفل/);
  assertMatch(block, /مشجع مرح/);
  assertMatch(block, /يكلم بابا أو ماما/);
  assertMatch(block, /مشاكل فلوس البيت/);
});

Deno.test("child tone: the chat prompt carries it for a child, and the Groq fallback too", async () => {
  const { buildChatSystemPrompt, groqSystemFor } = await import("./index.ts");
  const child = { family: { mine: { role: "child", alias: "سارة" } } };
  assertMatch(buildChatSystemPrompt(child), /بتكلم طفل/);
  assertEquals(/بتكلم طفل/.test(buildChatSystemPrompt({ family: { mine: { role: "admin" } } })), false);
  assertMatch(groqSystemFor(child), /بتكلم طفل/);
});
