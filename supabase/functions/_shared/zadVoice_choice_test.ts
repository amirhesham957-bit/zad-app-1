// صوت زاد اختيار العميل في «ملفي» (20261004090000) — نفس زاد، بصوت بنت أو ولد.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import {
  buildTtsPrompt,
  EMOTION_DIRECTIONS,
  MALE_EMOTION_DIRECTIONS,
  VOICE_EMOTIONS,
  voiceEmotionalRange,
  voiceNameFor,
  ZAD_MALE_VOICE,
  ZAD_VOICE,
  zadVoiceGender,
} from "./zadVoice.ts";

Deno.test("zad voice: only an explicit male choice is a boy's voice", () => {
  assertEquals(zadVoiceGender("male"), "male");
  for (const v of ["female", null, undefined, "", "Male", "robot", 1]) assertEquals(zadVoiceGender(v), "female");
  assertEquals(voiceNameFor("female"), ZAD_VOICE);
  assertEquals(voiceNameFor("male"), ZAD_MALE_VOICE);
  assert((ZAD_MALE_VOICE as string) !== ZAD_VOICE);
});

Deno.test("zad voice: the TTS prompt describes the chosen voice, with that voice's delivery", () => {
  const girl = buildTtsPrompt({ text: "صباح الخير", emotion: "cheerful", country: "EG" });
  const boy = buildTtsPrompt({ text: "صباح الخير", emotion: "cheerful", country: "EG", voice: "male" });
  assertStringIncludes(girl, "woman");
  assertStringIncludes(girl, EMOTION_DIRECTIONS.cheerful);
  assertStringIncludes(boy, "a young, friendly, very natural-sounding man");
  assertStringIncludes(boy, MALE_EMOTION_DIRECTIONS.cheerful);
  assertEquals(boy.includes("woman"), false);
});

Deno.test("zad voice: every emotion has a boy's delivery, and none of them is romantic", () => {
  for (const e of VOICE_EMOTIONS) {
    assert(MALE_EMOTION_DIRECTIONS[e]?.length > 20, e);
    assertEquals(/\bshe\b|\bher\b|fond of|flirt|romantic/i.test(MALE_EMOTION_DIRECTIONS[e]), false, e);
  }
  // البنت كمان: «تصبح على خير» دافية لصاحب أو حد من العيلة، مش لحد «she is truly fond of».
  assertEquals(/fond of|flirt|romantic/i.test(EMOTION_DIRECTIONS.tender), false);
});

Deno.test("zad voice: the emotional range speaks of Zad in the chosen gender", () => {
  assertStringIncludes(voiceEmotionalRange("female"), "بتهزري");
  assertStringIncludes(voiceEmotionalRange("male"), "بتهزر");
  assertEquals(voiceEmotionalRange("male").includes("بتهزري"), false);
  assertEquals(voiceEmotionalRange("female").includes("بدلع"), false);
});

Deno.test("inferEmotion: an emoji is read whole, not by half of its surrogate pair", async () => {
  const { inferEmotion } = await import("./zadVoice.ts");
  assertEquals(inferEmotion("تمام 😊"), "warm");
  assertEquals(inferEmotion("شكراً 🙏"), "warm");
  assertEquals(inferEmotion("يلا ❤️"), "warm");
  assertEquals(inferEmotion("زعلان 😢"), "sad");
  assertEquals(inferEmotion("⚠️ خلي بالك"), "worried");
  assertEquals(inferEmotion("خلصت 🎉"), "proud");
  assertEquals(inferEmotion("😂 حلوة دي"), "playful");
});
