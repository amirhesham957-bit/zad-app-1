import { assert, assertEquals } from "jsr:@std/assert@1";
import { apifyKeyExhausted, apifyTokens, flyerLinkSample, renderInput, renderPageWithApify } from "./apifyPool.ts";

const env = (vars: Record<string, string>) => (n: string) => vars[n];

Deno.test("apifyTokens: one secret with seven keys, numbered secrets, no duplicates", () => {
  const seven = Array.from({ length: 7 }, (_, i) => `apify_api_key${i}xxxxxxxx`);
  assertEquals(apifyTokens(env({ APIFY_API_TOKEN: seven.join(",\n ") })), seven);
  assertEquals(
    apifyTokens(env({ APIFY_API_TOKEN: seven[0], APIFY_API_TOKEN_1: seven[0], APIFY_API_TOKEN_2: seven[1] })),
    [seven[0], seven[1]],
  );
  assertEquals(apifyTokens(env({})), []);
  assertEquals(apifyTokens(env({ APIFY_API_TOKEN: "short" })), []);
});

Deno.test("apifyKeyExhausted: a refused or spent key moves on, a server error does not", () => {
  for (const s of [401, 402, 403, 429]) assert(apifyKeyExhausted(s));
  for (const s of [200, 400, 404, 408, 500, 502]) assert(!apifyKeyExhausted(s));
});

Deno.test("renderInput: one page, no proxy, robots.txt respected", () => {
  const input = renderInput("https://example.com/offers");
  assertEquals(input.startUrls, [{ url: "https://example.com/offers" }]);
  assertEquals(input.maxPagesPerCrawl, 1);
  assertEquals(input.respectRobotsTxtFile, true);
  assertEquals(input.proxyConfiguration, { useApifyProxy: false });
});

function fakeApify(statusByKey: Record<string, number>, html = "<html><a href='/f.pdf'>x</a></html>") {
  const seen: string[] = [];
  const fn = ((_url: string, init: RequestInit) => {
    const key = String((init.headers as Record<string, string>)["Authorization"]).replace("Bearer ", "");
    seen.push(key);
    const status = statusByKey[key] ?? 200;
    const body = status === 200 ? JSON.stringify([{ url: "https://example.com/", html }]) : JSON.stringify({ error: { type: "x" } });
    return Promise.resolve(new Response(body, { status }));
  }) as unknown as typeof fetch;
  return { fn, seen };
}

Deno.test("renderPageWithApify: a spent key (402) and a rate-limited one (429) pass to the next", async () => {
  const keys = ["key-a-0000000", "key-b-0000000", "key-c-0000000"];
  const { fn, seen } = fakeApify({ "key-a-0000000": 402, "key-b-0000000": 429 });
  const r = await renderPageWithApify("https://example.com/", keys, { fetchFn: fn, start: 0 });
  assert(r.ok);
  assertEquals(r.ok && r.key_index, 2);
  assertEquals(seen, keys);
});

Deno.test("renderPageWithApify: every key spent says so, and a server error stops at once", async () => {
  const keys = ["key-a-0000000", "key-b-0000000"];
  const spent = fakeApify({ "key-a-0000000": 402, "key-b-0000000": 401 });
  const r = await renderPageWithApify("https://example.com/", keys, { fetchFn: spent.fn, start: 1 });
  assertEquals(r, { ok: false, reason: "key_402", tried: 2 });
  assertEquals(spent.seen, ["key-b-0000000", "key-a-0000000"]);

  const broken = fakeApify({ "key-a-0000000": 500 });
  const r2 = await renderPageWithApify("https://example.com/", keys, { fetchFn: broken.fn, start: 0 });
  assertEquals(r2, { ok: false, reason: "apify_500", tried: 1 });
  assertEquals(broken.seen.length, 1);
});

Deno.test("renderPageWithApify: no keys = no call", async () => {
  const { fn, seen } = fakeApify({});
  assertEquals(await renderPageWithApify("https://example.com/", [], { fetchFn: fn }), { ok: false, reason: "no_apify_keys", tried: 0 });
  assertEquals(seen.length, 0);
});

Deno.test("flyerLinkSample: absolute PDF links and flyer pictures, nothing else", () => {
  const html = `<a href="/media/weekly-offers.pdf?v=2">PDF</a>
    <img src="https://cdn.shop.com/leaflet/page1.jpg"> <img src="/logo.png">
    <a href="https://shop.com/about">about</a> <div data-src="flyer/p2.webp"></div>`;
  assertEquals(flyerLinkSample(html, "https://shop.com/offers/"), {
    pdfs: ["https://shop.com/media/weekly-offers.pdf?v=2"],
    images: ["https://cdn.shop.com/leaflet/page1.jpg", "https://shop.com/offers/flyer/p2.webp"],
  });
});
