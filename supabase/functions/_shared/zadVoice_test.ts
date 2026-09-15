import { assert, assertEquals, assertMatch, assertStringIncludes } from "jsr:@std/assert@1";
import {
  accentDirection,
  buildTtsPrompt,
  countryCode,
  EMOTION_DIRECTIONS,
  emotionForMoment,
  inferEmotion,
  isVoiceEmotion,
  MOMENT_EMOTIONS,
  PERSONA_VOICES,
  VOICE_EMOTIONS,
  voiceForPersona,
} from "./zadVoice.ts";

Deno.test("every emotion has a performance direction and every moment maps to a real emotion", () => {
  for (const e of VOICE_EMOTIONS) assert(EMOTION_DIRECTIONS[e].length > 40, e);
  for (const [moment, emotion] of Object.entries(MOMENT_EMOTIONS)) assert(isVoiceEmotion(emotion), moment);
});

Deno.test("the full emotional range the user asked for is present", () => {
  for (const e of ["playful", "reproachful", "sulky", "sad", "cheerful", "proud"]) assert(isVoiceEmotion(e), e);
  assertMatch(EMOTION_DIRECTIONS.sad, /tears|trembl/);
  assertMatch(EMOTION_DIRECTIONS.sulky, /pout|sulk/i);
});

Deno.test("accent follows the account country, including Arabic names and Turkey", () => {
  assertStringIncludes(accentDirection("EG"), "Egyptian");
  assertStringIncludes(accentDirection("مصر"), "Egyptian");
  assertStringIncludes(accentDirection("sa"), "Saudi");
  assertStringIncludes(accentDirection("TR"), "Turkish");
  assertStringIncludes(accentDirection(null), "Match the language");
  assertEquals(countryCode("constructor"), null);
});

Deno.test("the sender's moment decides the emotion; text is only the fallback", () => {
  assertEquals(emotionForMoment("dose_missed"), "reproachful");
  assertEquals(emotionForMoment("dose_missed_again"), "sad");
  assertEquals(emotionForMoment("morning_greeting"), "cheerful");
  assertEquals(emotionForMoment("unknown_moment", "⛔ وصلت لحد ميزانيتك"), "worried");
  assertEquals(emotionForMoment(undefined, "مبروك حققت هدفك"), "proud");
});

Deno.test("text inference keeps the old notification-reader cues", () => {
  assertEquals(inferEmotion("⚠️ ميزانيتك قاربت النفاد"), "worried");
  assertEquals(inferEmotion("ميعاد جرعة دوا الضغط"), "caring");
  assertEquals(inferEmotion("صباح الخير يا قمر"), "cheerful");
  assertEquals(inferEmotion("كده برضه؟ نسيت الدوا تاني"), "reproachful");
  assertEquals(inferEmotion("تمام"), "warm");
});

Deno.test("prompt keeps the directive-before / generate-after shape and carries accent + delivery", () => {
  const p = buildTtsPrompt({ text: "افطر وخد دواك", emotion: "caring", country: "EG" });
  assert(p.startsWith("Read the following text aloud"));
  assert(p.trimEnd().endsWith("Now generate the speech audio for this text."));
  assertStringIncludes(p, "Egyptian");
  assertStringIncludes(p, EMOTION_DIRECTIONS.caring);
  assertStringIncludes(p, "\nافطر وخد دواك\n");
});

Deno.test("persona voices stay identical to the live-call table", async () => {
  const { LIVE_VOICE_BY_PERSONA } = await import("../zad-voice-live/protocol.ts");
  assertEquals(PERSONA_VOICES, LIVE_VOICE_BY_PERSONA);
  assertEquals(voiceForPersona("sarah_warm"), "Aoede");
  assertEquals(voiceForPersona("nope"), "Aoede");
});

Deno.test("the same moment is said with the feeling its situation calls for, never sad without a reason", async () => {
  const { emotionRangeForMoment, situationalEmotion } = await import("./zadVoice.ts");
  const cairoNoon = Date.parse("2026-09-15T09:00:00Z"); // ١٢ الضهر في القاهرة
  const cairoLate = Date.parse("2026-09-15T20:30:00Z"); // ١١:٣٠ بالليل
  const tz = { time_zone: "Africa/Cairo" };
  assertEquals(situationalEmotion("appointment_soon", { ...tz, kind: "medical" }, cairoNoon), "caring");
  assertEquals(situationalEmotion("appointment_soon", { ...tz, kind: "personal", recurrence: "hourly" }, cairoNoon), "playful");
  assertEquals(situationalEmotion("appointment_soon", { ...tz, kind: "work" }, cairoNoon), "warm");
  assertEquals(situationalEmotion("appointment_soon", { ...tz, kind: "personal" }, cairoLate), "tender");
  assertEquals(situationalEmotion("dose_due", tz, Date.parse("2026-09-15T05:00:00Z")), "cheerful");
  // مفيش عتاب بالليل على جرعة فاتت.
  assertEquals(situationalEmotion("dose_missed", tz, cairoLate), "caring");
  assertEquals(situationalEmotion("dose_missed", tz, cairoNoon), "reproachful");
  for (const m of ["appointment_soon", "dose_due", "morning_greeting", "good_night", "goal_achieved", "receipt_reaction"]) {
    const range = emotionRangeForMoment(m);
    assert(!range.includes("sad") && !range.includes("reproachful") && !range.includes("sulky"), `${m} must not sound upset`);
  }
});
