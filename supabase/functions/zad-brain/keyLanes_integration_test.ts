// The lanes end to end: a background request that meets 429s walks only its reserved
// keys and never reaches a customer's; a customer request walks its own keys first.
//
// A fresh copy of callModel.ts (the query string) with its own six-key pool, so the
// module-level pool other test files build is not shared.
import { assert, assertEquals } from "jsr:@std/assert@1";

Deno.env.set("ZAD_PROVIDER", "gemini");
for (let n = 1; n <= 6; n++) Deno.env.set(`ZAD_API_KEY_${n}`, `lane-k${n}`);
Deno.env.set("ZAD_MODEL_FALLBACKS", "lane-model-b");
Deno.env.delete("ZAD_BACKGROUND_KEYS");

const { callModel, inLane, setModelCooldownMsForTests } = await import("./callModel.ts?lanes");
setModelCooldownMsForTests(0);
// The copy has read them; don't leave six keys for a test file that runs after this one.
for (let n = 1; n <= 6; n++) Deno.env.delete(`ZAD_API_KEY_${n}`);
Deno.env.delete("ZAD_MODEL_FALLBACKS");

const BASE = {
  model: "lane-model-a",
  system: "s",
  tools: [],
  history: [{ role: "user" as const, text: "hi" }],
};

function keyOf(url: string): string {
  return decodeURIComponent(url.match(/key=([^&]+)/)?.[1] ?? "");
}

function stub(handler: (url: string) => Response) {
  const keys: string[] = [];
  const original = globalThis.fetch;
  globalThis.fetch = ((input: string | URL | Request) => {
    const url = String(input);
    if (url.includes("generativelanguage")) keys.push(keyOf(url));
    return Promise.resolve(handler(url));
  }) as typeof fetch;
  return { keys, restore: () => { globalThis.fetch = original; } };
}

const quota = () => new Response(JSON.stringify({ error: { code: 429 } }), { status: 429 });
const ok = () =>
  new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: "تمام" }] } }] }), { status: 200 });

Deno.test("background work only ever reaches the two reserved keys", async () => {
  const s = stub(() => quota());
  try {
    await inLane("background", () => callModel({ ...BASE })).catch(() => null);
    assert(s.keys.length > 0);
    assertEquals([...new Set(s.keys)].sort(), ["lane-k5", "lane-k6"]);
  } finally {
    s.restore();
  }
});

Deno.test("a customer walks their four keys before borrowing the reserved two", async () => {
  const s = stub(() => quota());
  try {
    await callModel({ ...BASE }).catch(() => null);
    const firstModel = s.keys.slice(0, 6);
    assertEquals(new Set(firstModel.slice(0, 4)), new Set(["lane-k1", "lane-k2", "lane-k3", "lane-k4"]));
    assertEquals(new Set(firstModel.slice(4)), new Set(["lane-k5", "lane-k6"]));
  } finally {
    s.restore();
  }
});

Deno.test("a background request that succeeds used a reserved key", async () => {
  const s = stub(() => ok());
  try {
    const reply = await inLane("background", () => callModel({ ...BASE }));
    assertEquals(reply.text, "تمام");
    assert(["lane-k5", "lane-k6"].includes(s.keys[0]));
  } finally {
    s.restore();
  }
});
