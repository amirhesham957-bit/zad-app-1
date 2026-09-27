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
