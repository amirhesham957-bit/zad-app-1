import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  buildGatewayUrl,
  engineKey,
  nextRoute,
  percentile,
  planRoutes,
  type Route,
  skipOpenRoutes,
  stateOf,
  summarizeTrial,
} from "./gatewayRouting.ts";

const G = (model: string, viaGateway = false): Route => ({ provider: "gemini", model, viaGateway });
const Q = (model: string, viaGateway = false): Route => ({ provider: "groq", model, viaGateway });
const base = { hasVision: false, gatewayEnabled: false, geminiModels: ["g-a", "g-b"], groqModel: "q-1" };

Deno.test("vision never routes to groq, even when groq is configured", () => {
  const chain = planRoutes({ ...base, hasVision: true });
  assertEquals(chain.some((r) => r.provider === "groq"), false);
  assertEquals(chain.map((r) => r.model), ["g-a", "g-b"]);
});

Deno.test("vision with no gemini models gives empty chain (groq stays out)", () => {
  assertEquals(planRoutes({ ...base, hasVision: true, geminiModels: [] }), []);
});

Deno.test("order: gemini models in order, groq last", () => {
  assertEquals(planRoutes(base), [G("g-a"), G("g-b"), Q("q-1")]);
});

Deno.test("empty and blank models are dropped; blank groq omitted", () => {
  const chain = planRoutes({ ...base, geminiModels: ["  ", " g-x ", ""], groqModel: " " });
  assertEquals(chain, [G("g-x")]);
});

Deno.test("nothing valid gives empty chain", () => {
  assertEquals(planRoutes({ hasVision: false, gatewayEnabled: true, geminiModels: [], groqModel: "" }), []);
});

Deno.test("gatewayEnabled sets viaGateway on every route", () => {
  assertEquals(planRoutes({ ...base, gatewayEnabled: true }), [G("g-a", true), G("g-b", true), Q("q-1", true)]);
});

Deno.test("buildGatewayUrl builds gemini and groq urls", () => {
  assertEquals(
    buildGatewayUrl({ accountId: "acc_1", gatewayId: "gw-2", provider: "gemini" }),
    "https://gateway.ai.cloudflare.com/v1/acc_1/gw-2/google-ai-studio",
  );
  assertEquals(
    buildGatewayUrl({ accountId: "acc_1", gatewayId: "gw-2", provider: "groq" }),
    "https://gateway.ai.cloudflare.com/v1/acc_1/gw-2/groq",
  );
});

Deno.test("buildGatewayUrl rejects invalid ids", () => {
  for (const bad of ["", "a/b", "a b", "a.b", "x?y"]) {
    assertThrows(() => buildGatewayUrl({ accountId: bad, gatewayId: "gw", provider: "groq" }));
    assertThrows(() => buildGatewayUrl({ accountId: "acc", gatewayId: bad, provider: "groq" }));
  }
});

Deno.test("nextRoute: no failures returns first route; empty chain returns null", () => {
  assertEquals(nextRoute([G("g-a"), Q("q-1")], []), G("g-a"));
  assertEquals(nextRoute([], []), null);
  assertEquals(nextRoute([], [{ status: 500 }]), null);
});

Deno.test("nextRoute: 429, 5xx and network (0) advance to next route", () => {
  const chain = [G("g-a"), G("g-b"), Q("q-1")];
  assertEquals(nextRoute(chain, [{ status: 429 }]), G("g-b"));
  assertEquals(nextRoute(chain, [{ status: 503 }]), G("g-b"));
  assertEquals(nextRoute(chain, [{ status: 0 }]), G("g-b"));
  assertEquals(nextRoute(chain, [{ status: 500 }, { status: 502 }]), Q("q-1"));
});

Deno.test("nextRoute: 401/403 skip the rest of that provider", () => {
  const chain = [G("g-a"), G("g-b"), Q("q-1")];
  assertEquals(nextRoute(chain, [{ status: 401 }]), Q("q-1"));
  assertEquals(nextRoute(chain, [{ status: 403 }]), Q("q-1"));
});

Deno.test("nextRoute: 400 returns null (no retry)", () => {
  assertEquals(nextRoute([G("g-a"), Q("q-1")], [{ status: 400 }]), null);
});

Deno.test("nextRoute: exhausted chain returns null", () => {
  const chain = [G("g-a"), G("g-b"), Q("q-1")];
  assertEquals(nextRoute(chain, [{ status: 429 }, { status: 429 }, { status: 500 }]), null);
  assertEquals(nextRoute(chain, [{ status: 403 }, { status: 500 }]), null);
});

Deno.test("nextRoute: replay keeps position after a skip", () => {
  const chain = [G("g-a"), G("g-b"), Q("q-1"), Q("q-2")];
  // 403 on g-a skips g-b, so the next try is q-1; its 429 moves to q-2 (not back to g-b)
  assertEquals(nextRoute(chain, [{ status: 403 }, { status: 429 }]), Q("q-2"));
});

Deno.test("percentile: nearest-rank, empty is null", () => {
  assertEquals(percentile([10, 20, 30, 40], 50), 20);
  assertEquals(percentile([10, 20, 30, 40], 95), 40);
  assertEquals(percentile([7], 95), 7);
  assertEquals(percentile([], 50), null);
});

Deno.test("summarizeTrial: empty input gives nulls and zero counts", () => {
  assertEquals(summarizeTrial([]), {
    direct: { n: 0, p50: null, p95: null },
    gateway: { n: 0, p50: null, p95: null, cacheHitRate: null },
    deltaP50Ms: null,
  });
});

Deno.test("summarizeTrial: splits direct and gateway, delta and cache hit rate", () => {
  const s = summarizeTrial([
    { viaGateway: false, ms: 100 },
    { viaGateway: false, ms: 200 },
    { viaGateway: false, ms: 300 },
    { viaGateway: true, ms: 50, cacheHit: true },
    { viaGateway: true, ms: 80, cacheHit: false },
    { viaGateway: true, ms: 90 },
  ]);
  assertEquals(s.direct, { n: 3, p50: 200, p95: 300 });
  assertEquals(s.gateway, { n: 3, p50: 80, p95: 90, cacheHitRate: 1 / 3 });
  assertEquals(s.deltaP50Ms, -120);
});

Deno.test("summarizeTrial: delta null when one side is empty", () => {
  const s = summarizeTrial([{ viaGateway: true, ms: 40, cacheHit: true }]);
  assertEquals(s.direct.p50, null);
  assertEquals(s.deltaP50Ms, null);
  assertEquals(s.gateway.cacheHitRate, 1);
});

Deno.test("breaker: closed and missing states keep the whole chain", () => {
  const chain = [G("g-a"), G("g-b"), Q("q-1")];
  assertEquals(skipOpenRoutes(chain, {}), chain);
  assertEquals(skipOpenRoutes(chain, null), chain);
  assertEquals(skipOpenRoutes(chain, { "gemini:g-a": "closed" }), chain);
  assertEquals(stateOf({ x: "garbage" }, "x"), "closed");
});

Deno.test("breaker: an open engine is skipped, the next route stays", () => {
  const chain = [G("g-a"), G("g-b"), Q("q-1")];
  assertEquals(skipOpenRoutes(chain, { [engineKey(chain[0])]: "open" }), [G("g-b"), Q("q-1")]);
});

Deno.test("breaker: half_open is kept (it is the probe)", () => {
  const chain = [G("g-a"), G("g-b")];
  assertEquals(skipOpenRoutes(chain, { "gemini:g-a": "half_open" }), chain);
});

Deno.test("breaker: all open falls back to the full chain", () => {
  const chain = [G("g-a"), Q("q-1")];
  assertEquals(skipOpenRoutes(chain, { "gemini:g-a": "open", "groq:q-1": "open" }), chain);
});
