// Tavily (ZAD_PLAN ٤.١٤): النتايج من غير ملخّص الموديل، والفحص بيقول السبب ومابيطلّعش المفتاح.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { resetTavilyRotation, restFor, tavilyKeys, tavilyProbe, tavilySearch, tavilySearchRotating, type TavilyResult } from "./tavily.ts";

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
  assertEquals(await tavilyProbe(undefined), { configured: false, keys: 0 });
  stubFetch(401, { detail: { error: "Unauthorized: invalid API key SECRET-KEY" } });
  const bad = await tavilyProbe("SECRET-KEY");
  assertEquals(bad, { configured: true, keys: 1, working: 0, failed: [{ status: 401, reason: "Unauthorized: invalid API key …" }], ok: false, status: 401, reason: "Unauthorized: invalid API key …", results: 0 });
  assert(!JSON.stringify(bad).includes("SECRET"));
  // الباقة المجانية خلصت: Tavily بيرجع 432.
  stubFetch(432, { detail: { error: "This request exceeds your plan's set usage limit." } });
  assertEquals((await tavilyProbe("k")).status, 432);
  stubFetch(200, { results: [{ title: "t", url: "https://x.com", content: "c" }] });
  assertEquals(await tavilyProbe("k"), { configured: true, keys: 1, working: 1, ok: true, status: 200, results: 1 });
  globalThis.fetch = realFetch;
});

Deno.test("tavily keys: main + numbered + comma list, trimmed and de-duplicated", () => {
  const env = (m: Record<string, string>) => (k: string) => m[k];
  assertEquals(tavilyKeys(env({})), []);
  assertEquals(tavilyKeys(env({ TAVILY_API_KEY: "a, b", TAVILY_API_KEY_1: " b ", TAVILY_API_KEY_7: "c", TAVILY_API_KEY_2: "  " })), ["a", "b", "c"]);
});

Deno.test("tavily rotation: round-robin, a spent key rests and the next one answers", async () => {
  resetTavilyRotation();
  const calls: string[] = [];
  const ok = (items = 1): TavilyResult => ({ ok: true, status: 200, items: Array(items).fill({ title: "t", url: "u", snippet: "s" }) });
  const fake = (spent: Set<string>) => (key: string) => {
    calls.push(key);
    return Promise.resolve(spent.has(key) ? { ok: false, status: 432, items: [] } as TavilyResult : ok());
  };
  const keys = ["k1", "k2", "k3"];
  await tavilySearchRotating(keys, "q", 1, 0, fake(new Set()));
  await tavilySearchRotating(keys, "q", 1, 0, fake(new Set()));
  assertEquals(calls, ["k1", "k2"]); // الحمل بيتوزّع
  calls.length = 0;
  const r = await tavilySearchRotating(keys, "q", 1, 0, fake(new Set(["k3", "k1"])));
  assertEquals(calls, ["k3", "k1", "k2"]); // k3 وk1 خلصوا، k2 ردّ
  assertEquals([r.ok, r.tried, r.total], [true, 3, 3]);
  calls.length = 0;
  await tavilySearchRotating(keys, "q", 1, 1000, fake(new Set(["k3", "k1"])));
  assertEquals(calls, ["k2"]); // الاتنين مرتاحين فمش بيتجرّبوا
  calls.length = 0;
  const all = await tavilySearchRotating(keys, "q", 1, 1000, fake(new Set(keys)));
  assertEquals([all.ok, all.status], [false, 432]);
  const none = await tavilySearchRotating(keys, "q", 1, 1000, fake(new Set(keys)));
  assertEquals([none.ok, none.tried], [false, 0]); // الكل بيرتاح
  assertEquals(restFor(500), 0);
  resetTavilyRotation();
});

Deno.test("tavily probe: counts working keys and never prints a key", async () => {
  let n = 0;
  globalThis.fetch = (() => Promise.resolve(new Response(JSON.stringify({ results: [] }), { status: n++ === 0 ? 200 : 432 }))) as typeof fetch;
  const p = await tavilyProbe(["SECRET-A", "SECRET-B"]);
  assertEquals([p.keys, p.working], [2, 1]);
  assert(!JSON.stringify(p).includes("SECRET"));
  globalThis.fetch = realFetch;
});
