// The owner's 2/11 rule end to end: with ZAD_PAID_KEY_1 set, every customer call reaches the paid key
// and nothing else, while the test account (lane "internal") reaches the free keys and never the paid one.
//
// A fresh copy of callModel.ts (the query string) so its key pool is this file's alone.
import { assert, assertEquals } from "jsr:@std/assert@1";

Deno.env.set("ZAD_PROVIDER", "gemini");
Deno.env.set("ZAD_PAID_KEY_1", "paid-k1");
for (let n = 1; n <= 3; n++) Deno.env.set(`ZAD_API_KEY_${n}`, `free-k${n}`);
Deno.env.set("ZAD_MODEL_FALLBACKS", "paid-model-b");
Deno.env.delete("ZAD_EVAL_KEY");

const { callModel, inLane, setModelCooldownMsForTests } = await import("./callModel.ts?paidlane");
setModelCooldownMsForTests(0);
Deno.env.delete("ZAD_PAID_KEY_1");
for (let n = 1; n <= 3; n++) Deno.env.delete(`ZAD_API_KEY_${n}`);
Deno.env.delete("ZAD_MODEL_FALLBACKS");

const BASE = { model: "paid-model-a", system: "s", tools: [], history: [{ role: "user" as const, text: "hi" }] };

function stub() {
  const keys: string[] = [];
  const original = globalThis.fetch;
  globalThis.fetch = ((input: string | URL | Request) => {
    const url = String(input);
    if (url.includes("generativelanguage")) keys.push(decodeURIComponent(url.match(/key=([^&]+)/)?.[1] ?? ""));
    return Promise.resolve(new Response(JSON.stringify({ error: { code: 429 } }), { status: 429 }));
  }) as typeof fetch;
  return { keys, restore: () => { globalThis.fetch = original; } };
}

for (const lane of ["customer", "paid", "free", "background"] as const) {
  Deno.test(`${lane}: customer data reaches the paid key only, even when it is out of quota`, async () => {
    const s = stub();
    try {
      await inLane(lane, () => callModel({ ...BASE })).catch(() => null);
      assert(s.keys.length > 0);
      assertEquals([...new Set(s.keys)], ["paid-k1"]);
    } finally {
      s.restore();
    }
  });
}

Deno.test("the test account walks the free keys and never the paid one", async () => {
  const s = stub();
  try {
    await inLane("internal", () => callModel({ ...BASE })).catch(() => null);
    assert(s.keys.length > 0);
    assertEquals([...new Set(s.keys)].sort(), ["free-k1", "free-k2", "free-k3"]);
  } finally {
    s.restore();
  }
});
