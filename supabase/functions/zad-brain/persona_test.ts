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
