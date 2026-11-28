// P3.4: قاطع الدايرة وتتبع اللفات حوالين callModel. الـstore مزيّف في الذاكرة (الحقيقي RPC على Postgres،
// واختباره في supabase/sql/tests/round_trace_breaker_test.sql). المهم هنا: open بيتخطى، half_open بيجرّب،
// closed عادي، وأي فشل في القاطع أو التتبع مايوقّفش اللفة.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.env.set("ZAD_PROVIDER", "gemini");
Deno.env.set("ZAD_API_KEY_1", "k1");
Deno.env.set("GROQ_API_KEY_1", "groq1");
Deno.env.set("ZAD_MODEL_FALLBACKS", "model-b,model-c");

const { callModel, setModelCooldownMsForTests } = await import("./callModel.ts");
import type { BreakerStore, RoundRecord } from "./engineBreaker.ts";
const { setBreakerStoreForTests } = await import("./engineBreaker.ts");
setModelCooldownMsForTests(0);

const BASE = {
  model: "model-a",
  system: "s",
  tools: [{ name: "t", description: "d", input_schema: { type: "object", properties: {} } }],
  history: [{ role: "user" as const, text: "hi" }],
};

const modelOf = (url: string) => url.match(/models\/([^:]+):/)?.[1] ?? "";
const ok = () =>
  new Response(
    JSON.stringify({
      candidates: [{ content: { parts: [{ text: "تمام" }] } }],
      usageMetadata: { promptTokenCount: 5, candidatesTokenCount: 2 },
    }),
    { status: 200 },
  );
const overloaded = () => new Response(JSON.stringify({ error: { code: 503, status: "UNAVAILABLE" } }), { status: 503 });

function stub(handler: (model: string) => Response) {
  const tried: string[] = [];
  const original = globalThis.fetch;
  globalThis.fetch = ((input: string | URL | Request) => {
    const m = modelOf(String(input));
    tried.push(m);
    return Promise.resolve(handler(m));
  }) as typeof fetch;
  return { tried, restore: () => { globalThis.fetch = original; } };
}

function fakeStore(states: Record<string, string>, opts: { gateThrows?: boolean; recordThrows?: boolean } = {}) {
  const rounds: RoundRecord[] = [];
  const store: BreakerStore = {
    gate: () => opts.gateThrows ? Promise.reject(new Error("db down")) : Promise.resolve(states),
    record: (r) => {
      rounds.push(r);
      return opts.recordThrows ? Promise.reject(new Error("db down")) : Promise.resolve();
    },
  };
  return { store, rounds };
}

Deno.test("breaker closed: normal order, the round is traced as ok", async () => {
  const f = fakeStore({});
  setBreakerStoreForTests(f.store);
  const s = stub(() => ok());
  try {
    await callModel({ ...BASE });
    assertEquals(s.tried, ["model-a"]);
    assertEquals(f.rounds.map((r) => [r.engine, r.ok]), [["gemini:model-a", true]]);
  } finally {
    s.restore();
    setBreakerStoreForTests(undefined);
  }
});

Deno.test("breaker open: the engine is skipped and the next route answers", async () => {
  const f = fakeStore({ "gemini:model-a": "open" });
  setBreakerStoreForTests(f.store);
  const s = stub(() => ok());
  try {
    const reply = await callModel({ ...BASE });
    assertEquals(reply.text, "تمام");
    assertEquals(s.tried, ["model-b"]);
  } finally {
    s.restore();
    setBreakerStoreForTests(undefined);
  }
});

Deno.test("breaker half_open: the engine gets its probe", async () => {
  const f = fakeStore({ "gemini:model-a": "half_open" });
  setBreakerStoreForTests(f.store);
  const s = stub(() => ok());
  try {
    await callModel({ ...BASE });
    assertEquals(s.tried, ["model-a"]);
  } finally {
    s.restore();
    setBreakerStoreForTests(undefined);
  }
});

Deno.test("a failed engine is traced as an error and the chain moves on", async () => {
  const f = fakeStore({});
  setBreakerStoreForTests(f.store);
  const s = stub((m) => (m === "model-a" ? overloaded() : ok()));
  try {
    await callModel({ ...BASE });
    assertEquals(f.rounds.map((r) => [r.engine, r.ok]), [["gemini:model-a", false], ["gemini:model-b", true]]);
  } finally {
    s.restore();
    setBreakerStoreForTests(undefined);
  }
});

Deno.test("fail open: a dead breaker store never blocks the turn", async () => {
  const f = fakeStore({}, { gateThrows: true, recordThrows: true });
  setBreakerStoreForTests(f.store);
  const s = stub(() => ok());
  try {
    const reply = await callModel({ ...BASE });
    assertEquals(reply.text, "تمام");
    assertEquals(s.tried, ["model-a"]);
  } finally {
    s.restore();
    setBreakerStoreForTests(undefined);
  }
});

Deno.test("fail open: a gate that never answers is cut off and the turn still runs", async () => {
  const hang: BreakerStore = { gate: () => new Promise(() => {}), record: () => Promise.resolve() };
  setBreakerStoreForTests(hang);
  const s = stub(() => ok());
  try {
    const reply = await callModel({ ...BASE });
    assertEquals(reply.text, "تمام");
  } finally {
    s.restore();
    setBreakerStoreForTests(undefined);
  }
});

Deno.test("no store (no env): callModel works and writes nothing", async () => {
  setBreakerStoreForTests(null);
  const s = stub(() => ok());
  try {
    assertEquals((await callModel({ ...BASE })).text, "تمام");
  } finally {
    s.restore();
    setBreakerStoreForTests(undefined);
  }
});
