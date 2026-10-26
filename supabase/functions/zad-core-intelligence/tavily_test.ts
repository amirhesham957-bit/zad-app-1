// Tavily (ZAD_PLAN ٤.١٤): النتايج من غير ملخّص الموديل، والفحص بيقول السبب ومابيطلّعش المفتاح.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { tavilyProbe, tavilySearch } from "./tavily.ts";

const realFetch = globalThis.fetch;
function stubFetch(status: number, body: unknown, seen: Request[] = []) {
  globalThis.fetch = ((input: string | URL, init?: RequestInit) => {
    seen.push(new Request(String(input), init));
    return Promise.resolve(new Response(JSON.stringify(body), { status }));
  }) as typeof fetch;
  return seen;
}

Deno.test("tavily: pages with links, never the model's own answer", async () => {
  const seen = stubFetch(200, {
    answer: "مانشستر سيتي 2023",
    results: [{ title: "عروض كارفور", url: "https://carrefouregypt.com/offers", content: "زيت ٧٢ جنيه" }, { title: "من غير رابط" }],
  });
  const r = await tavilySearch("KEY", "عروض كارفور", 5);
  assertEquals(r, { ok: true, status: 200, items: [{ title: "عروض كارفور", url: "https://carrefouregypt.com/offers", snippet: "زيت ٧٢ جنيه" }] });
  assertEquals(seen[0].headers.get("Authorization"), "Bearer KEY");
  assertEquals((await seen[0].json()).include_answer, false);
  globalThis.fetch = realFetch;
});

Deno.test("tavily probe: not configured, or Tavily's reason — never the key", async () => {
  assertEquals(await tavilyProbe(undefined), { configured: false });
  stubFetch(401, { detail: { error: "Unauthorized: invalid API key SECRET-KEY" } });
  const bad = await tavilyProbe("SECRET-KEY");
  assertEquals(bad, { configured: true, ok: false, status: 401, reason: "Unauthorized: invalid API key …", results: 0 });
  assert(!JSON.stringify(bad).includes("SECRET"));
  // الباقة المجانية خلصت: Tavily بيرجع 432.
  stubFetch(432, { detail: { error: "This request exceeds your plan's set usage limit." } });
  assertEquals((await tavilyProbe("k")).status, 432);
  stubFetch(200, { results: [{ title: "t", url: "https://x.com", content: "c" }] });
  assertEquals(await tavilyProbe("k"), { configured: true, ok: true, status: 200, results: 1 });
  globalThis.fetch = realFetch;
});
