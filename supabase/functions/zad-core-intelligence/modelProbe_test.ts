import { assertEquals } from "jsr:@std/assert@1";
import { geminiQuotaNote, gemmaModelsFrom, modelQuotaProbe, sharedGroqSlots, type ProbeRow } from "./modelProbe.ts";

const QUOTA_429 = {
  error: {
    code: 429,
    message: "You exceeded your current quota",
    details: [{
      "@type": "type.googleapis.com/google.rpc.QuotaFailure",
      violations: [{
        quotaMetric: "generativelanguage.googleapis.com/generate_content_free_tier_requests",
        quotaId: "GenerateRequestsPerDayPerProjectPerModel-FreeTier",
        quotaValue: "20",
      }],
    }],
  },
};

Deno.test("a Gemini 429 names the project's own limit", () => {
  assertEquals(geminiQuotaNote(QUOTA_429), "GenerateRequestsPerDayPerProjectPerModel-FreeTier=20");
  assertEquals(geminiQuotaNote({ error: { message: "model not found" } }), "model not found");
  assertEquals(geminiQuotaNote(null), null);
});

Deno.test("Gemma 4 is found from ListModels, only where it can generate", () => {
  assertEquals(gemmaModelsFrom({
    models: [
      { name: "models/gemma-4-27b-it", supportedGenerationMethods: ["generateContent"] },
      { name: "models/gemma-4-embed", supportedGenerationMethods: ["embedContent"] },
      { name: "models/gemma-3-12b-it", supportedGenerationMethods: ["generateContent"] },
    ],
  }), ["gemma-4-27b-it"]);
  assertEquals(gemmaModelsFrom({}), []);
});

function groqRow(slot: number, model: string, remaining: number | null): ProbeRow {
  return {
    provider: "groq", key_slot: slot, model, status: 200, ok: true, limit_requests: 1000,
    remaining_requests: remaining, limit_tokens: 8000, remaining_tokens: 7999, quota_note: null,
  };
}

Deno.test("two Groq keys whose counter drops by one in a row look like one organization", () => {
  assertEquals(sharedGroqSlots([groqRow(1, "m", 999), groqRow(2, "m", 998), groqRow(3, "m", 999)]), [[1, 2]]);
  // Separate organizations, both untouched today: the same count, not a drop.
  assertEquals(sharedGroqSlots([groqRow(1, "m", 999), groqRow(2, "m", 999)]), []);
});

Deno.test("the probe reports per model, with no key in the result", async () => {
  const fakeFetch = ((input: string | URL | Request, init?: RequestInit) => {
    const url = String(input);
    if (url.includes("/models?")) return Promise.resolve(new Response(JSON.stringify({ models: [] }), { status: 200 }));
    if (url.includes("generativelanguage")) {
      const key = new Headers(init?.headers).get("x-goog-api-key");
      return Promise.resolve(key === "g2"
        ? new Response(JSON.stringify(QUOTA_429), { status: 429 })
        : new Response(JSON.stringify({ candidates: [] }), { status: 200 }));
    }
    return Promise.resolve(new Response("{}", {
      status: 200,
      headers: { "x-ratelimit-limit-requests": "1000", "x-ratelimit-remaining-requests": "999", "x-ratelimit-limit-tokens": "8000" },
    }));
  }) as typeof fetch;
  const report = await modelQuotaProbe(["g1", "g2"], ["q1"], fakeFetch, { geminiModels: ["gemini-x"], groqModels: ["openai/gpt-oss-20b"] });
  assertEquals(report.summary["gemini:gemini-x"].keys_ok, 1);
  assertEquals(report.summary["gemini:gemini-x"].keys_total, 2);
  assertEquals(report.summary["gemini:gemini-x"].notes, ["429 GenerateRequestsPerDayPerProjectPerModel-FreeTier=20"]);
  assertEquals(report.summary["groq:openai/gpt-oss-20b"].notes, ["rpd=1000 tpm=8000"]);
  assertEquals(JSON.stringify(report).includes("g1") || JSON.stringify(report).includes("q1"), false);
});
