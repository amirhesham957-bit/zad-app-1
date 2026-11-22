import { assertEquals } from "jsr:@std/assert@1";
import {
  applyCacheHints, type CacheRequest, compareBeforeAfter, readUsage, splitStablePrefix, summarizeTimings,
  toSystemBlocks, type SystemPart,
} from "./promptCache.ts";

const parts = (snap: string, time: string): SystemPart[] => [
  { kind: "snapshot", text: snap },
  { kind: "tools", text: "T" },
  { kind: "time", text: time },
  { kind: "rules", text: "R" },
  { kind: "user", text: "U" },
  { kind: "soul", text: "S" },
];

Deno.test("split: stable first in fixed order, volatile keeps order", () => {
  const { stable, volatile } = splitStablePrefix(parts("a", "t"));
  assertEquals(stable.map((p) => p.kind), ["rules", "soul", "tools"]);
  assertEquals(volatile.map((p) => p.kind), ["snapshot", "time", "user"]);
});

Deno.test("stable bytes identical across calls with different volatile data", () => {
  const a = splitStablePrefix(parts("snap1", "10:00")).stable;
  const b = splitStablePrefix(parts("snap2", "11:00")).stable;
  assertEquals(JSON.stringify(a), JSON.stringify(b));
});

Deno.test("anthropic: cache_control on last stable block only, no stable flag", () => {
  const req = { model: "m", system: toSystemBlocks(parts("s", "t")) };
  const out = applyCacheHints("anthropic", req);
  const sys = out.system as any[];
  assertEquals(sys.map((b) => !!b.cache_control), [false, false, true, false, false, false]);
  assertEquals(sys.some((b) => "stable" in b), false);
  assertEquals(sys[2].cache_control, { type: "ephemeral" });
});

Deno.test("never mutates input", () => {
  const req = { system: toSystemBlocks(parts("s", "t")) };
  const snap = JSON.stringify(req);
  for (const p of ["anthropic", "gemini", "openai_compatible", "zzz"]) applyCacheHints(p, req);
  assertEquals(JSON.stringify(req), snap);
});

Deno.test("others: stable-first string, no cache_control; unknown passthrough", () => {
  const req: CacheRequest = {
    system: [
      { type: "text" as const, text: "V" },
      { type: "text" as const, text: "S", stable: true },
    ],
  };
  assertEquals(applyCacheHints("openai_compatible", req).system, "S\n\nV");
  assertEquals(applyCacheHints("gemini", req).system, "S\n\nV");
  assertEquals(applyCacheHints("mystery", req), req);
  assertEquals(applyCacheHints("anthropic", { system: "plain" }).system, "plain");
});

Deno.test("readUsage handles each provider shape", () => {
  assertEquals(readUsage({ input_tokens: 10, cache_read_input_tokens: 90 }), { input: 100, cached: 90 });
  assertEquals(
    readUsage({ prompt_tokens: 200, prompt_tokens_details: { cached_tokens: 150 } }),
    { input: 200, cached: 150 },
  );
  assertEquals(readUsage({ promptTokenCount: 300, cachedContentTokenCount: 100 }), { input: 300, cached: 100 });
  assertEquals(readUsage(undefined), { input: 0, cached: 0 });
});

Deno.test("summary and before/after", () => {
  const before = [
    { latencyMs: 4000, usage: { prompt_tokens: 1000 } },
    { latencyMs: 3000, usage: { prompt_tokens: 1000 } },
  ];
  const after = [
    { latencyMs: 2000, usage: { prompt_tokens: 1000, prompt_tokens_details: { cached_tokens: 800 } } },
    { latencyMs: 1000, usage: { prompt_tokens: 1000, prompt_tokens_details: { cached_tokens: 900 } } },
  ];
  assertEquals(summarizeTimings(after).hitRate, 0.85);
  assertEquals(summarizeTimings(after).meanMs, 1500);
  const c = compareBeforeAfter(before, after);
  assertEquals(c.meanDeltaMs, -2000);
  assertEquals(c.before.hitRate, 0);
  assertEquals(summarizeTimings([]).hitRate, 0);
});
