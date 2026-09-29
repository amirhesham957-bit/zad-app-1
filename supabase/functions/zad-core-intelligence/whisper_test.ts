import { assertEquals } from "jsr:@std/assert@1";
import { whisperOptions } from "./whisper.ts";

Deno.test("Arabic countries: ar, with their own dialect as the hint", () => {
  assertEquals(whisperOptions("EG").language, "ar");
  assertEquals(whisperOptions("مصر").prompt?.includes("دلوقتي"), true);
  assertEquals(whisperOptions("SA").prompt?.includes("أبغى"), true);
  assertEquals(whisperOptions("LB").prompt?.includes("هلق"), true);
  assertEquals(whisperOptions("MA").prompt?.includes("دابا"), true);
});

Deno.test("Turkey is transcribed as Turkish, not forced into Arabic", () => {
  assertEquals(whisperOptions("TR"), { language: "tr" });
});

Deno.test("an unknown country leaves the language to Whisper", () => {
  assertEquals(whisperOptions(null), {});
  assertEquals(whisperOptions("US"), {});
  assertEquals(whisperOptions(""), {});
});

import { spokenText } from "./whisper.ts";

Deno.test("spokenText: the YouTube outro Whisper invents on silence is not speech", () => {
  // بالظبط اللي ظهر على موبايل صاحب المشروع ٢٠٢٦-٠٩-٢٨، ٣ مرات ورا بعض.
  assertEquals(spokenText({ text: "اشتركوا في القناة" }), null);
  assertEquals(spokenText({ text: " اشتركوا في القناة. " }), null);
  assertEquals(spokenText({ text: "شكراً للمشاهدة" }), null);
  assertEquals(spokenText({ text: "Thanks for watching!" }), null);
  // جملة حقيقية فيها نفس الكلمات بتعدّي.
  assertEquals(spokenText({ text: "اشتركوا في القناة دي بـ 150 جنيه في الشهر" }), "اشتركوا في القناة دي بـ 150 جنيه في الشهر");
});

Deno.test("spokenText: segments Whisper marks as silence are dropped, speech is kept", () => {
  const data = {
    text: "صرفت ٥٠ جنيه قهوة اشتركوا في القناة",
    segments: [
      { text: "صرفت ٥٠ جنيه قهوة", no_speech_prob: 0.02, avg_logprob: -0.2 },
      { text: " اشتركوا في القناة", no_speech_prob: 0.9, avg_logprob: -1.4 },
    ],
  };
  assertEquals(spokenText(data), "صرفت ٥٠ جنيه قهوة");
  // كله صمت ⇒ مفيش كلام.
  assertEquals(spokenText({ text: "x", segments: [{ text: "موسيقى", no_speech_prob: 0.95, avg_logprob: -2 }] }), null);
  // كلام واطي بثقة كويسة مايتشالش حتى لو no_speech_prob عالي.
  assertEquals(spokenText({ segments: [{ text: "عايز أسجل مصروف", no_speech_prob: 0.7, avg_logprob: -0.3 }] }), "عايز أسجل مصروف");
});

Deno.test("spokenText: the dialect prompt echoed back on silence is not speech", () => {
  const prompt = whisperOptions("EG").prompt!;
  assertEquals(spokenText({ text: prompt }, prompt), null);
  assertEquals(spokenText({ text: "" }), null);
  assertEquals(spokenText(null), null);
});
