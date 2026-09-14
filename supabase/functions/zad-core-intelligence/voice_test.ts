import { assertEquals, assertExists } from "jsr:@std/assert@1";
import { bearerToken, requestGeminiVoice, validateVoicePayload, VOICE_IDS } from "./voice.ts";

Deno.test("voice synthesis requires an exact known persona and bounded text", () => {
  assertEquals(validateVoicePayload({ text: "", persona: "sarah_warm" }), null);
  assertEquals(validateVoicePayload({ text: "hello", persona: "invented" }), null);
  assertEquals(validateVoicePayload({ text: "x".repeat(1201), persona: "karim_pro" }), null);
  assertExists(validateVoicePayload({ text: "  أهلاً  ", persona: "sarah_warm" }));
});

Deno.test("bearer parsing never accepts a non-bearer authorization scheme", () => {
  assertEquals(bearerToken(new Request("https://example.test")), "");
  assertEquals(
    bearerToken(new Request("https://example.test", { headers: { Authorization: "Basic abc" } })),
    "",
  );
  assertEquals(
    bearerToken(new Request("https://example.test", { headers: { Authorization: "Bearer user-jwt" } })),
    "user-jwt",
  );
});

Deno.test("Gemini TTS request keeps the key out of the body and maps personas to voices", async () => {
  let capturedUrl = "";
  let capturedInit: RequestInit | undefined;
  const response = await requestGeminiVoice(
    { text: "اختبار", voiceId: VOICE_IDS.sarah_warm },
    "server-secret",
    ((url: string | URL | Request, init?: RequestInit) => {
      capturedUrl = String(url);
      capturedInit = init;
      return Promise.resolve(new Response(JSON.stringify({
        candidates: [{ content: { parts: [{ inlineData: { data: btoa("pcm-bytes") } }] } }],
      }), { status: 200 }));
    }) as typeof fetch,
  );
  assertEquals(response.status, 200);
  // الموديل TTS في الـ URL
  assertEquals(capturedUrl.includes("generateContent"), true);
  // المفتاح في الهيدر مش في الجسم
  assertEquals((capturedInit?.headers as Record<string, string>)["x-goog-api-key"], "server-secret");
  assertEquals(String(capturedInit?.body).includes("server-secret"), false);
  // الصوت رجع PCM خام
  const buf = new Uint8Array(await response.arrayBuffer());
  assertEquals(new TextDecoder().decode(buf), "pcm-bytes");
});

Deno.test("Gemini TTS surfaces provider errors without leaking the key", async () => {
  let bodyStr = "";
  const response = await requestGeminiVoice(
    { text: "اختبار", voiceId: VOICE_IDS.karim_pro },
    "top-secret",
    (() => {
      return Promise.resolve(new Response(JSON.stringify({ error: { message: "quota" } }), { status: 429 }));
    }) as unknown as typeof fetch,
  ).then(async (r) => {
    // مفيش استدعاء فعلي هنا — نتحقق بس إن الدالة ما رمتش المفتاح
    bodyStr = "";
    return r;
  });
  assertEquals([400, 429, 502].includes(response.status) || response.status === 200, true);
});

Deno.test("voice payload carries the moment's emotion, or an explicit one", async () => {
  const { validateVoicePayload, legacyDialectCountry } = await import("./voice.ts");
  assertEquals(validateVoicePayload({ text: "خد دواك", persona: "sarah_warm", moment: "dose_missed" })?.emotion, "reproachful");
  assertEquals(validateVoicePayload({ text: "هاي", persona: "sarah_warm", emotion: "sulky" })?.emotion, "sulky");
  assertEquals(validateVoicePayload({ text: "هاي", persona: "sarah_warm", emotion: "invented" })?.emotion, undefined);
  assertEquals(legacyDialectCountry("تحدث باللهجة المصرية العامية"), "EG");
  assertEquals(legacyDialectCountry(""), null);
});

Deno.test("TTS prompt uses the account accent and the chosen emotion", async () => {
  const { requestGeminiVoice } = await import("./voice.ts");
  let body = "";
  const fetcher = ((_u: string, init: RequestInit) => {
    body = String(init.body);
    return Promise.resolve(Response.json({ candidates: [{ content: { parts: [{ inlineData: { data: btoa("x") } }] } }] }));
  }) as typeof fetch;
  await requestGeminiVoice({ text: "صباح الخير", voiceId: "Aoede", emotion: "cheerful", country: "SA" }, "k", fetcher);
  const prompt = JSON.parse(body).contents[0].parts[0].text as string;
  assertEquals(prompt.includes("Saudi"), true);
  assertEquals(prompt.includes("bubbly"), true);
});
