import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  alertSpeechText,
  geminiKeysFromEnv,
  pcmToMp3,
  synthesizeAlertPcm,
  wantsVoice,
} from "./voiceAlert.ts";

Deno.test("only an explicit voice:true asks for a voice note", () => {
  assert(wantsVoice({ user_id: "u", title: "t", body: "b", voice: true }));
  assert(!wantsVoice({ user_id: "u", title: "t", body: "b" }));
  assert(!wantsVoice({ voice: "true" }));
  assert(!wantsVoice(null));
});

Deno.test("speech text drops emoji and markdown, keeps the words", () => {
  const text = alertSpeechText("⛔ وصلت لحد ميزانيتك", "مصروف الشهر: *5000* من 5000 (100%)");
  assertEquals(text, "وصلت لحد ميزانيتك. مصروف الشهر: 5000 من 5000 (100%)");
  assert(!/\p{Extended_Pictographic}/u.test(alertSpeechText("🔔 زاد لاحظ إن إشعارات البنك وقفت ⚠️", "")));
});

Deno.test("long alerts are cut at a sentence end, under the cap", () => {
  const body = "جملة أولى مهمة جداً. ".repeat(40);
  const text = alertSpeechText("تنبيه", body, 120);
  assert(text.length <= 120);
  assert(text.endsWith("."));
});

Deno.test("PCM becomes a real MPEG layer III stream", () => {
  const rate = 24000;
  const pcm = new Int16Array(rate);
  for (let i = 0; i < pcm.length; i++) pcm[i] = Math.round(Math.sin(2 * Math.PI * 440 * i / rate) * 8000);
  const mp3 = pcmToMp3(new Uint8Array(pcm.buffer));
  assert(mp3.length > 1000);
  // frame sync: 11 bits set
  assertEquals(mp3[0], 0xff);
  assertEquals(mp3[1] & 0xe0, 0xe0);
});

Deno.test("TTS rotates past a rate-limited key and returns the audio bytes", async () => {
  const calls: string[] = [];
  const audio = btoa(String.fromCharCode(1, 2, 3, 4));
  const fetcher = ((_url: string, init: RequestInit) => {
    const key = (init.headers as Record<string, string>)["x-goog-api-key"];
    calls.push(key);
    const body = JSON.parse(String(init.body));
    assertEquals(body.generationConfig.speechConfig.voiceConfig.prebuiltVoiceConfig.voiceName, "Aoede");
    if (key === "k1") return Promise.resolve(new Response("{}", { status: 429 }));
    return Promise.resolve(Response.json({ candidates: [{ content: { parts: [{ inlineData: { data: audio } }] } }] }));
  }) as typeof fetch;
  const pcm = await synthesizeAlertPcm("تنبيه", ["k1", "k2"], fetcher);
  assertEquals(Array.from(pcm ?? []), [1, 2, 3, 4]);
  assertEquals(calls, ["k1", "k2"]);
});

Deno.test("TTS gives up quietly when every key fails", async () => {
  const fetcher = (() => Promise.resolve(new Response("{}", { status: 503 }))) as typeof fetch;
  assertEquals(await synthesizeAlertPcm("تنبيه", ["k1", "k2"], fetcher), null);
  assertEquals(await synthesizeAlertPcm("تنبيه", [], fetcher), null);
});

Deno.test("key pool matches the other functions: numbered keys first, legacy fallback", () => {
  const env: Record<string, string> = { ZAD_API_KEY_1: "a", ZAD_API_KEY_3: "c", GEMINI_API_KEY: "legacy" };
  assertEquals(geminiKeysFromEnv((n) => env[n]), ["a", "c"]);
  assertEquals(geminiKeysFromEnv((n) => ({ GEMINI_API_KEY: "legacy" } as Record<string, string>)[n]), ["legacy"]);
});

Deno.test("alert emotion: explicit emotion, then the moment, then the text", async () => {
  const { alertEmotion } = await import("./voiceAlert.ts");
  assertEquals(alertEmotion({ emotion: "sulky", moment: "budget_100" }, ""), "sulky");
  assertEquals(alertEmotion({ moment: "budget_100" }, "⛔ وصلت لحد ميزانيتك"), "sad");
  assertEquals(alertEmotion({}, "⛔ وصلت لحد ميزانيتك"), "worried");
});

Deno.test("voice note prompt carries the account accent and the emotion", async () => {
  let prompt = "";
  const fetcher = ((_u: string, init: RequestInit) => {
    prompt = JSON.parse(String(init.body)).contents[0].parts[0].text;
    return Promise.resolve(Response.json({ candidates: [{ content: { parts: [{ inlineData: { data: btoa("x") } }] } }] }));
  }) as typeof fetch;
  await synthesizeAlertPcm("كده برضه؟", ["k"], fetcher, { emotion: "reproachful", country: "EG" });
  assert(prompt.includes("Egyptian"));
  assert(prompt.includes("reproachful"));
});
