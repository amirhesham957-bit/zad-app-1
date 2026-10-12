// The plan lanes end to end (freeLane.ts, keyLanes.ts): a subscriber's turn tries the
// key held for subscribers first; a free turn never touches it; and a free turn past
// the day's budget goes straight to Groq without a single Gemini request.
//
// A fresh copy of callModel.ts with its own five-key pool and a Groq key.
import { assert, assertEquals } from "jsr:@std/assert@1";

Deno.env.set("ZAD_PROVIDER", "gemini");
for (let n = 1; n <= 5; n++) Deno.env.set(`ZAD_API_KEY_${n}`, `plan-k${n}`);
Deno.env.set("GROQ_API_KEY_1", "plan-groq");
Deno.env.set("ZAD_MODEL_FALLBACKS", "plan-model-b");
Deno.env.delete("ZAD_BACKGROUND_KEYS");
Deno.env.delete("ZAD_PAID_KEYS");

const { callModel, inLane, setModelCooldownMsForTests } = await import("./callModel.ts?planlanes");
setModelCooldownMsForTests(0);
for (let n = 1; n <= 5; n++) Deno.env.delete(`ZAD_API_KEY_${n}`);
Deno.env.delete("GROQ_API_KEY_1");
Deno.env.delete("ZAD_MODEL_FALLBACKS");

const BASE = { model: "plan-model-a", system: "s", tools: [], history: [{ role: "user" as const, text: "hi" }] };

function stub(gemini: () => Response) {
  const keys: string[] = [];
  let groq = 0;
  const original = globalThis.fetch;
  globalThis.fetch = ((input: string | URL | Request) => {
    const url = String(input);
    if (url.includes("generativelanguage")) {
      keys.push(decodeURIComponent(url.match(/key=([^&]+)/)?.[1] ?? ""));
      return Promise.resolve(gemini());
    }
    groq++;
    return Promise.resolve(new Response(JSON.stringify({
      choices: [{ message: { content: "من جروك" } }], usage: { prompt_tokens: 1, completion_tokens: 1 },
    }), { status: 200 }));
  }) as typeof fetch;
  return { keys, groqCalls: () => groq, restore: () => { globalThis.fetch = original; } };
}

const quota = () => new Response(JSON.stringify({ error: { code: 429 } }), { status: 429 });
const ok = () => new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: "تمام" }] } }] }), { status: 200 });

// Five keys: k5 for the cron, k4 for subscribers, k1–k3 shared.
Deno.test("a subscriber's turn tries the subscribers' key first", async () => {
  const s = stub(ok);
  try {
    const reply = await inLane("paid", () => callModel({ ...BASE }));
    assertEquals(reply.text, "تمام");
    assertEquals(s.keys[0], "plan-k4");
  } finally {
    s.restore();
  }
});

Deno.test("a free turn never reaches the subscribers' key, even when everything else is full", async () => {
  const s = stub(quota);
  try {
    await inLane("free", () => callModel({ ...BASE })).catch(() => null);
    assert(s.keys.length > 0);
    assertEquals(s.keys.includes("plan-k4"), false);
  } finally {
    s.restore();
  }
});

Deno.test("a free turn past the day's budget goes to Groq without one Gemini request", async () => {
  const s = stub(ok);
  try {
    const reply = await inLane("free_busy", () => callModel({ ...BASE }));
    assertEquals(reply.text, "من جروك");
    assertEquals(s.keys.length, 0);
    assertEquals(s.groqCalls(), 1);
  } finally {
    s.restore();
  }
});
