import { assertEquals, assertMatch } from "jsr:@std/assert@1";
import { buildVoiceSystemInstruction, conversationProfile } from "./persona.ts";

Deno.test("persona follows the account country, or the customer's own dialect choice", () => {
  assertEquals(conversationProfile("EG").locale, "ar-EG");
  assertEquals(conversationProfile("SA").locale, "ar-SA");
  assertEquals(conversationProfile("تركيا").locale, "tr-TR");
  assertEquals(conversationProfile("SA", "EG").locale, "ar-EG");
});

Deno.test("voice system instruction never drops the honest-AI-disclosure rule", () => {
  const text = buildVoiceSystemInstruction("EG");
  assertMatch(text, /مساعدة ذكاء اصطناعي/);
  assertMatch(text, /من غير خداع/);
});

Deno.test("voice system instruction asks for speech-sized turns and follows dialect", () => {
  const eg = buildVoiceSystemInstruction("EG");
  assertMatch(eg, /جملك قصيرة/);
  assertMatch(eg, /اتكلم مصري/);
  const sa = buildVoiceSystemInstruction("SA");
  assertMatch(sa, /تكلم سعودي/);
});

Deno.test("live call carries the shared emotional range, and still discloses it is an AI", async () => {
  const { VOICE_EMOTIONAL_RANGE } = await import("../_shared/zadVoice.ts");
  const text = buildVoiceSystemInstruction("EG");
  assertMatch(text, /بتتقمصي/);
  assertMatch(text, /مساعدة ذكاء اصطناعي/);
  assertEquals(text.includes(VOICE_EMOTIONAL_RANGE), true);
});
