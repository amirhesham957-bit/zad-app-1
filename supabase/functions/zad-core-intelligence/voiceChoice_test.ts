// صوت زاد اختيار العميل في «ملفي» (20261003130000): Gemini بصوت الولد وAzure بالصوت الرجالي لنفس البلد.
import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { azureVoiceFor } from "./azureVoice.ts";
import { requestGeminiVoice } from "./voice.ts";
import { ZAD_MALE_VOICE, ZAD_VOICE } from "../_shared/zadVoice.ts";

Deno.test("voice choice: Azure follows the chosen voice within the account's country", () => {
  assertEquals(azureVoiceFor("إزيك", "EG", ZAD_VOICE), "ar-EG-SalmaNeural");
  assertEquals(azureVoiceFor("إزيك", "EG", ZAD_MALE_VOICE), "ar-EG-ShakirNeural");
  assertEquals(azureVoiceFor("شخبارك", "SA", ZAD_MALE_VOICE), "ar-SA-HamedNeural");
  assertEquals(azureVoiceFor("Merhaba", "TR", ZAD_MALE_VOICE), "tr-TR-AhmetNeural");
});

Deno.test("voice choice: Gemini is asked for the boy's voice and a boy's delivery", async () => {
  let sent: any = null;
  const fetcher = ((_url: string, init: RequestInit) => {
    sent = JSON.parse(String(init.body));
    return Promise.resolve(new Response(JSON.stringify({ candidates: [{ content: { parts: [{ inlineData: { data: btoa("pcm") } }] } }] })));
  }) as unknown as typeof fetch;
  await requestGeminiVoice({ text: "أهلاً", voiceId: ZAD_MALE_VOICE, voice: "male", country: "EG", emotion: "warm" }, "k", fetcher);
  assertEquals(sent.generationConfig.speechConfig.voiceConfig.prebuiltVoiceConfig.voiceName, ZAD_MALE_VOICE);
  assertStringIncludes(sent.contents[0].parts[0].text, "natural-sounding man");
});
