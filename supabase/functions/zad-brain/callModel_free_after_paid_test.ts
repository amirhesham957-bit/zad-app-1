// ZAD_FREE_AFTER_PAID (المالك ١٢/١١): المدفوع خلص على السلسلة كلها ⇒ نفس السلسلة على المجاني قبل جروك.
// ملف لوحده: المسابح ثوابت بتتقري وقت الاستيراد، فالـenv لازم يتظبط قبله (زي callModel_failover_test.ts).
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.env.set("ZAD_PROVIDER", "gemini");
Deno.env.set("ZAD_PAID_KEY_1", "paid1");
Deno.env.set("ZAD_API_KEY_1", "free1");
Deno.env.set("ZAD_API_KEY_2", "free2");
Deno.env.set("GROQ_API_KEY_1", "groq1");
Deno.env.set("ZAD_MODEL_FALLBACKS", "model-b");
Deno.env.set("ZAD_FREE_AFTER_PAID", "1");

const { callModel, setModelCooldownMsForTests } = await import("./callModel.ts?free-after-paid");
// The pools are read; leave no key behind for the test files that run after this one in the same process.
for (const k of ["ZAD_PAID_KEY_1", "ZAD_API_KEY_1", "ZAD_API_KEY_2", "GROQ_API_KEY_1", "ZAD_MODEL_FALLBACKS", "ZAD_FREE_AFTER_PAID"]) {
  Deno.env.delete(k);
}
setModelCooldownMsForTests(0);

const BASE = {
  model: "model-a",
  system: "s",
  tools: [],
  history: [{ role: "user" as const, text: "hi" }],
};

const quota429 = () =>
  new Response(JSON.stringify({ error: { code: 429, details: [] } }), { status: 429 });
const geminiOk = () =>
  new Response(
    JSON.stringify({ candidates: [{ content: { parts: [{ text: "تمام" }] } }], usageMetadata: {} }),
    { status: 200 },
  );

Deno.test("the paid key spent on every model ⇒ the free keys answer before Groq", async () => {
  const calls: string[] = [];
  const original = globalThis.fetch;
  globalThis.fetch = ((input: string | URL | Request) => {
    const url = String(input);
    calls.push(url);
    if (url.includes("groq")) return Promise.resolve(new Response("{}", { status: 500 }));
    return Promise.resolve(url.includes("key=paid1") ? quota429() : geminiOk());
  }) as typeof fetch;
  try {
    const reply = await callModel(BASE);
    assertEquals(reply.text, "تمام");
    // The paid key was tried on both models first, and Groq never.
    assert(calls.filter((u) => u.includes("key=paid1")).length >= 2, calls.join("\n"));
    assert(calls.some((u) => /key=free[12]/.test(u)));
    assert(!calls.some((u) => u.includes("groq")));
  } finally {
    globalThis.fetch = original;
  }
});
