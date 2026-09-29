// اختبارات مسبح مفاتيح TTS: 429 على مفتاح → ينط للمفتاح التالي،
// و404 على موديل → ينط للموديل الاحتياطي بنفس المفتاح. كل النداءات mock fetcher.
import { assertEquals } from "jsr:@std/assert@1";
import { freshTtsPool, requestGeminiVoiceWithPool, ttsKeyOrder } from "./voice.ts";

function audioResponse(): Response {
  return new Response(
    JSON.stringify({
      candidates: [{ content: { parts: [{ inlineData: { data: btoa("pcm-bytes") } }] } }],
    }),
    { status: 200 },
  );
}

Deno.test("TTS pool: 429 على المفتاح الأول ينط للتاني ويرجّع صوت", async () => {
  const calls: Array<{ key: string; model: string }> = [];
  const mockFetcher: typeof fetch = (input, init) => {
    const url = String(input);
    const key = String(((init as RequestInit)?.headers as Record<string, string> | undefined)?.["x-goog-api-key"] ?? "");
    const model = url.split("/models/")[1]?.split(":")[0] ?? "";
    calls.push({ key, model });
    if (key === "KEY1") return Promise.resolve(new Response("rate limited", { status: 429 }));
    return Promise.resolve(audioResponse());
  };
  const res = await requestGeminiVoiceWithPool(
    { text: "مرحبا", voiceId: "Kore" } as any,
    ["KEY1", "KEY2"],
    mockFetcher,
    "",
    undefined,
    freshTtsPool(),
  );
  assertEquals(res.status, 200);
  assertEquals(calls.length, 2);
  assertEquals(calls[0].key, "KEY1");
  assertEquals(calls[1].key, "KEY2");
  // نص المفتاح مايبانش في أي رد
  const bodyText = await res.clone().text();
  assertEquals(bodyText.includes("KEY1") || bodyText.includes("KEY2"), false);
});

Deno.test("TTS pool: 404 على الموديل الأساسي ينط للاحتياطي بنفس المفتاح", async () => {
  const calls: Array<{ key: string; model: string; status: number }> = [];
  const mockFetcher: typeof fetch = (input, init) => {
    const url = String(input);
    const key = String(((init as RequestInit)?.headers as Record<string, string> | undefined)?.["x-goog-api-key"] ?? "");
    const model = url.split("/models/")[1]?.split(":")[0] ?? "";
    calls.push({ key, model, status: 0 });
    if (model === "primary-model") return Promise.resolve(new Response("not found", { status: 404 }));
    return Promise.resolve(audioResponse());
  };
  const res = await requestGeminiVoiceWithPool(
    { text: "مرحبا", voiceId: "Kore" } as any,
    ["KEY1"],
    mockFetcher,
    "",
    ["primary-model", "fallback-model"],
    freshTtsPool(),
  );
  assertEquals(res.status, 200);
  assertEquals(calls.length, 2);
  assertEquals(calls[0].model, "primary-model");
  assertEquals(calls[1].model, "fallback-model");
  assertEquals(calls[1].key, "KEY1");
});

Deno.test("TTS pool: استنفاد المسبح كله يرجّع 502 بمحاولات مبرهنة بدون مفاتيح", async () => {
  const mockFetcher: typeof fetch = () => Promise.resolve(new Response("down", { status: 500 }));
  const res = await requestGeminiVoiceWithPool(
    { text: "مرحبا", voiceId: "Kore" } as any,
    ["KEY1", "KEY2"],
    mockFetcher,
    "",
    ["m1", "m2"],
    freshTtsPool(),
  );
  assertEquals(res.status, 502);
  const body = await res.json();
  assertEquals(Array.isArray(body.attempts), true);
  assertEquals(body.attempts.length, 2); // 5xx = مشكلة مفتاح → محاولة واحدة لكل مفتاح
  const serialized = JSON.stringify(body);
  assertEquals(serialized.includes("KEY1") || serialized.includes("KEY2"), false);
});

Deno.test("TTS pool: 503 على موديل ينقل للاحتياطي ومايتجربش تاني بباقي المفاتيح", async () => {
  const calls: Array<{ key: string; model: string }> = [];
  const mockFetcher: typeof fetch = (input, init) => {
    const url = String(input);
    const key = String(((init as RequestInit)?.headers as Record<string, string> | undefined)?.["x-goog-api-key"] ?? "");
    const model = url.split("/models/")[1]?.split(":")[0] ?? "";
    calls.push({ key, model });
    if (model === "busy") return Promise.resolve(new Response("high demand", { status: 503 }));
    if (key === "KEY1") return Promise.resolve(new Response("rate limited", { status: 429 }));
    return Promise.resolve(audioResponse());
  };
  const res = await requestGeminiVoiceWithPool(
    { text: "مرحبا", voiceId: "Kore" } as any,
    ["KEY1", "KEY2", "KEY3"],
    mockFetcher,
    "",
    ["busy", "calm"],
    freshTtsPool(),
  );
  assertEquals(res.status, 200);
  assertEquals(calls, [
    { key: "KEY1", model: "busy" },
    { key: "KEY1", model: "calm" },
    { key: "KEY2", model: "calm" },
  ]);
});

Deno.test("TTS pool: مفيش مفاتيح أصلاً يرجّع 503 صريح", async () => {
  const res = await requestGeminiVoiceWithPool(
    { text: "مرحبا", voiceId: "Kore" } as any,
    [],
    () => Promise.resolve(audioResponse()),
  );
  assertEquals(res.status, 503);
});

Deno.test("TTS pool: each request starts at the next key", () => {
  const pool = freshTtsPool();
  assertEquals(ttsKeyOrder(3, pool, 0), [0, 1, 2]);
  assertEquals(ttsKeyOrder(3, pool, 0), [1, 2, 0]);
  assertEquals(ttsKeyOrder(3, pool, 0), [2, 0, 1]);
  assertEquals(ttsKeyOrder(3, pool, 0), [0, 1, 2]);
});

Deno.test("TTS pool: a key that answered 429 is tried last for a minute", async () => {
  const pool = freshTtsPool();
  const calls: string[] = [];
  const fetcher: typeof fetch = (_input, init) => {
    const key = String(((init as RequestInit)?.headers as Record<string, string>)["x-goog-api-key"]);
    calls.push(key);
    return Promise.resolve(key === "KEY1" ? new Response("rate limited", { status: 429 }) : audioResponse());
  };
  let t = 1_000;
  const clock = () => t;
  await requestGeminiVoiceWithPool({ text: "أ", voiceId: "Kore" } as any, ["KEY1", "KEY2"], fetcher, "", ["m"], pool, clock);
  // Next request would start at KEY2 anyway; the one after would start at KEY1 again —
  // but KEY1 is still cooling, so KEY2 goes first.
  await requestGeminiVoiceWithPool({ text: "ب", voiceId: "Kore" } as any, ["KEY1", "KEY2"], fetcher, "", ["m"], pool, clock);
  calls.length = 0;
  await requestGeminiVoiceWithPool({ text: "ج", voiceId: "Kore" } as any, ["KEY1", "KEY2"], fetcher, "", ["m"], pool, clock);
  assertEquals(calls, ["KEY2"]);
  // After the minute it is back in its turn.
  t += 61_000;
  assertEquals(ttsKeyOrder(2, pool, t)[0], 1);
  assertEquals(ttsKeyOrder(2, pool, t)[0], 0);
});

Deno.test("TTS pool: past the time budget Gemini is left for the fallback", async () => {
  let t = 0;
  const calls: string[] = [];
  const fetcher: typeof fetch = (_input, init) => {
    calls.push(String(((init as RequestInit)?.headers as Record<string, string>)["x-goog-api-key"]));
    t += 9_000; // every attempt is slow
    return Promise.resolve(new Response("down", { status: 500 }));
  };
  const res = await requestGeminiVoiceWithPool(
    { text: "مرحبا", voiceId: "Kore" } as any, ["K1", "K2", "K3", "K4", "K5"], fetcher, "", ["m"], freshTtsPool(), () => t,
  );
  assertEquals(res.status, 502);
  assertEquals(calls.length, 2); // 0s, 9s — the third would start at 18s, past 15s
});
