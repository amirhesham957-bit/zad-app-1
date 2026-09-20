// احتياطي Azure TTS: الصوت الصح لكل بلد/لغة/شخصية، الـSSML مايتحقنش، وسقوط مسبح Gemini
// كله بيوصل Azure بنفس فورمات PCM. كل النداءات mock fetcher — مفيش شبكة.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { AZURE_OUTPUT_FORMAT, azureSpeechConfig, azureVoiceFor, buildAzureSsml, requestAzureVoice, speakableText } from "./azureVoice.ts";
import { requestVoiceWithFallback } from "./voice.ts";

const AZURE = { key: "AZ-SECRET", region: "westeurope" };

function geminiAudio(): Response {
  return new Response(JSON.stringify({ candidates: [{ content: { parts: [{ inlineData: { data: btoa("gemini-pcm") } }] } }] }), { status: 200 });
}

function router(handlers: { gemini: () => Response; azure: () => Response }) {
  const calls = { gemini: 0, azure: [] as Array<{ url: string; init: RequestInit }> };
  const fetcher: typeof fetch = (input, init) => {
    const url = String(input);
    if (url.includes("generativelanguage.googleapis.com")) {
      calls.gemini++;
      return Promise.resolve(handlers.gemini());
    }
    calls.azure.push({ url, init: init as RequestInit });
    return Promise.resolve(handlers.azure());
  };
  return { fetcher, calls };
}

Deno.test("config: المفتاح والريجن الاتنين لازم — وريجن فيه حروف غريبة يترفض", () => {
  assertEquals(azureSpeechConfig(() => undefined), null);
  assertEquals(azureSpeechConfig((n) => (n === "AZURE_SPEECH_KEY" ? "k" : undefined)), null);
  assertEquals(azureSpeechConfig((n) => ({ AZURE_SPEECH_KEY: "k", AZURE_SPEECH_REGION: "evil.com/x" } as Record<string, string>)[n]), null);
  assertEquals(azureSpeechConfig((n) => ({ AZURE_SPEECH_KEY: " k ", AZURE_SPEECH_REGION: "WestEurope" } as Record<string, string>)[n]), { key: "k", region: "westeurope" });
});

Deno.test("الصوت: بلد الحساب + لغة النص + الشخصية", () => {
  assertEquals(azureVoiceFor("إزيك يا حبيبي", "EG", "Aoede"), "ar-EG-SalmaNeural");
  assertEquals(azureVoiceFor("إزيك يا حبيبي", "مصر", "Charon"), "ar-EG-ShakirNeural");
  assertEquals(azureVoiceFor("هلا والله", "SA", "Leda"), "ar-SA-ZariyahNeural");
  assertEquals(azureVoiceFor("كيفك", "PS", "Aoede"), "ar-JO-SanaNeural");
  // بلد مش معروف ونص عربي = مصري؛ بلد تركي بس النص عربي = برضه صوت عربي
  assertEquals(azureVoiceFor("أهلاً", null, "Aoede"), "ar-EG-SalmaNeural");
  assertEquals(azureVoiceFor("أهلاً", "TR", "Aoede"), "ar-EG-SalmaNeural");
  assertEquals(azureVoiceFor("Günaydın, ilacını aldın mı?", "TR", "Aoede"), "tr-TR-EmelNeural");
  assertEquals(azureVoiceFor("Günaydın", null, "Charon"), "tr-TR-AhmetNeural");
  assertEquals(azureVoiceFor("Good morning", "EG", "Aoede"), "en-US-JennyNeural");
});

Deno.test("SSML: نص العميل مايقدرش يفتح وسم ويغيّر الصوت", () => {
  const ssml = buildAzureSsml(`</voice><voice name='en-US-GuyNeural'>hi & bye`, "ar-EG-SalmaNeural");
  assertEquals(ssml.match(/<voice /g)?.length, 1);
  assert(ssml.includes("&lt;/voice&gt;&lt;voice name=&apos;en-US-GuyNeural&apos;&gt;hi &amp; bye"));
  assert(ssml.includes("xml:lang='ar-EG'"));
});

Deno.test("الإيموجي بيتشال — مايكروسوفت كان هيقرا اسمها", () => {
  assertEquals(speakableText("مبروك 🎉🏆 حققت الهدف ❤️"), "مبروك حققت الهدف");
  assertEquals(speakableText("👨‍👩‍👧"), "");
});

Deno.test("نداء Azure: الهوست من الريجن، فورمات PCM 24kHz، والمفتاح في الهيدر بس", async () => {
  const { fetcher, calls } = router({ gemini: geminiAudio, azure: () => new Response(new Uint8Array([1, 2, 3, 4])) });
  const res = await requestAzureVoice({ text: "أهلاً 🎉", voiceId: "Aoede", country: "EG" }, AZURE, fetcher);
  assertEquals(res.status, 200);
  const { url, init } = calls.azure[0];
  assertEquals(url, "https://westeurope.tts.speech.microsoft.com/cognitiveservices/v1");
  const headers = init.headers as Record<string, string>;
  assertEquals(headers["X-Microsoft-OutputFormat"], AZURE_OUTPUT_FORMAT);
  assertEquals(AZURE_OUTPUT_FORMAT, "raw-24khz-16bit-mono-pcm");
  assertEquals(headers["Ocp-Apim-Subscription-Key"], "AZ-SECRET");
  assert(!String(init.body).includes("AZ-SECRET"));
  assert(!String(init.body).includes("🎉"));
});

Deno.test("نص إيموجي بس: مفيش نداء مدفوع على Azure", async () => {
  const { fetcher, calls } = router({ gemini: geminiAudio, azure: () => new Response(new Uint8Array([1])) });
  const res = await requestAzureVoice({ text: "🎉🎉", voiceId: "Aoede" }, AZURE, fetcher);
  assertEquals(res.status, 400);
  assertEquals(calls.azure.length, 0);
});

Deno.test("Gemini شغال: Azure مايتنادهش، والمشاعر فضلت عند Gemini", async () => {
  const { fetcher, calls } = router({ gemini: geminiAudio, azure: () => new Response(new Uint8Array([9])) });
  const res = await requestVoiceWithFallback({ text: "أهلاً", voiceId: "Aoede", emotion: "sad" }, ["G1"], AZURE, fetcher);
  assertEquals(res.status, 200);
  assertEquals(res.headers.get("X-Zad-Voice-Provider"), "gemini");
  assertEquals(new TextDecoder().decode(await res.arrayBuffer()), "gemini-pcm");
  assertEquals(calls.azure.length, 0);
});

Deno.test("كوتة Gemini خلصت على كل المفاتيح: Azure يرد بنفس PCM", async () => {
  const pcm = new Uint8Array([10, 20, 30, 40, 50, 60]);
  const { fetcher, calls } = router({ gemini: () => new Response("quota", { status: 429 }), azure: () => new Response(pcm) });
  const res = await requestVoiceWithFallback({ text: "دواك يا حبيبي", voiceId: "Aoede", country: "EG" }, ["G1", "G2", "G3"], AZURE, fetcher);
  assertEquals(res.status, 200);
  assertEquals(res.headers.get("Content-Type"), "audio/pcm");
  assertEquals(res.headers.get("X-Zad-Voice-Provider"), "azure");
  assertEquals(new Uint8Array(await res.arrayBuffer()), pcm);
  assertEquals(calls.gemini, 3);
  assertEquals(calls.azure.length, 1);
  assert(String(calls.azure[0].init.body).includes("ar-EG-SalmaNeural"));
});

Deno.test("مفيش مفاتيح Gemini خالص: Azure لوحده يكفي", async () => {
  const { fetcher, calls } = router({ gemini: geminiAudio, azure: () => new Response(new Uint8Array([7])) });
  const res = await requestVoiceWithFallback({ text: "أهلاً", voiceId: "Charon" }, [], AZURE, fetcher);
  assertEquals(res.status, 200);
  assertEquals(calls.gemini, 0);
  assert(String(calls.azure[0].init.body).includes("ar-EG-ShakirNeural"));
});

Deno.test("الاتنين وقعوا: 502 فيه محاولات Azure، ولا أي مادة مفتاح", async () => {
  const { fetcher } = router({ gemini: () => new Response("quota", { status: 429 }), azure: () => new Response("denied", { status: 401 }) });
  const res = await requestVoiceWithFallback({ text: "أهلاً", voiceId: "Aoede" }, ["G1"], AZURE, fetcher);
  assertEquals(res.status, 502);
  const body = await res.text();
  assert(body.includes(`"provider":"azure","status":401`));
  assert(!body.includes("G1") && !body.includes("AZ-SECRET"));
});

Deno.test("Azure مش متظبط: نفس سلوك قبل الاحتياطي (502) ومفيش نداء", async () => {
  const { fetcher, calls } = router({ gemini: () => new Response("quota", { status: 429 }), azure: () => new Response(new Uint8Array([1])) });
  const res = await requestVoiceWithFallback({ text: "أهلاً", voiceId: "Aoede" }, ["G1"], null, fetcher);
  assertEquals(res.status, 502);
  assertEquals(calls.azure.length, 0);
});
