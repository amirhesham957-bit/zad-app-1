import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { geminiKeys, groqKeys, MAX_KEYS } from "./keyPool.ts";

const envOf = (vars: Record<string, string>) => (n: string) => vars[n];

Deno.test("geminiKeys: reads past five — a sixth key is no longer ignored", () => {
  const vars: Record<string, string> = {};
  for (let n = 1; n <= 10; n++) vars[`ZAD_API_KEY_${n}`] = `g${n}`;
  assertEquals(geminiKeys(envOf(vars)).length, 10);
});

Deno.test("geminiKeys: a gap does not cut off the keys after it", () => {
  assertEquals(geminiKeys(envOf({ ZAD_API_KEY_1: "a", ZAD_API_KEY_7: "b" })), ["a", "b"]);
});

Deno.test("geminiKeys: duplicates and blanks drop out", () => {
  assertEquals(
    geminiKeys(envOf({ ZAD_API_KEY_1: "a", ZAD_API_KEY_2: " a ", ZAD_API_KEY_3: "  " })),
    ["a"],
  );
});

Deno.test("geminiKeys: legacy singular only when no numbered key is set", () => {
  assertEquals(geminiKeys(envOf({ GEMINI_API_KEY: "old" })), ["old"]);
  assertEquals(geminiKeys(envOf({ ZAD_API_KEY: "z", GEMINI_API_KEY: "old" })), ["z"]);
  assertEquals(geminiKeys(envOf({ ZAD_API_KEY_2: "n", GEMINI_API_KEY: "old" })), ["n"]);
  assertEquals(geminiKeys(envOf({})), []);
});

Deno.test("geminiKeys: stops at MAX_KEYS", () => {
  const vars: Record<string, string> = { [`ZAD_API_KEY_${MAX_KEYS + 1}`]: "over" };
  assertEquals(geminiKeys(envOf(vars)), []);
});

Deno.test("groqKeys: numbered keys then the singular, deduped", () => {
  assertEquals(
    groqKeys(envOf({ GROQ_API_KEY_1: "a", GROQ_API_KEY_6: "f", GROQ_API_KEY: "a" })),
    ["a", "f"],
  );
  assertEquals(groqKeys(envOf({ GROQ_API_KEY: "s" })), ["s"]);
});
