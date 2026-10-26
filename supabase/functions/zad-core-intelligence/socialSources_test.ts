// يوتيوب وإنستجرام (ZAD_PLAN ٤.١١، ٤.١٢): الفحص بيقول السبب ومابيطلّعش المفتاح.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { instagramProbe, youtubeProbe, youtubeSearch } from "./socialSources.ts";

function stubFetch(routes: Array<[RegExp, number, unknown]>, seen: string[] = []) {
  globalThis.fetch = ((input: string | URL) => {
    const url = String(input);
    seen.push(url);
    const hit = routes.find(([r]) => r.test(url));
    return Promise.resolve(new Response(JSON.stringify(hit?.[2] ?? {}), { status: hit?.[1] ?? 404 }));
  }) as typeof fetch;
  return seen;
}
const realFetch = globalThis.fetch;

Deno.test("youtube: videos with links, newest window, in the customer's region", async () => {
  const seen = stubFetch([[/youtube\/v3\/search/, 200, {
    items: [
      { id: { videoId: "abc" }, snippet: { title: "عروض كارفور الأسبوع", channelTitle: "Carrefour Egypt", publishedAt: "2026-10-25T10:00:00Z" } },
      { id: { channelId: "x" }, snippet: { title: "قناة مش فيديو" } },
    ],
  }]]);
  const r = await youtubeSearch("SECRET", "عروض كارفور", "eg", { now: Date.parse("2026-10-26T00:00:00Z") });
  assertEquals(r.items, [{ id: "abc", title: "عروض كارفور الأسبوع", channel: "Carrefour Egypt", published_at: "2026-10-25T10:00:00Z", url: "https://www.youtube.com/watch?v=abc" }]);
  const url = new URL(seen[0]);
  assertEquals([url.searchParams.get("regionCode"), url.searchParams.get("publishedAfter")], ["EG", "2026-10-12T00:00:00.000Z"]);
  globalThis.fetch = realFetch;
});

Deno.test("youtube probe: says not configured, or the reason Google gave — never the key", async () => {
  assertEquals(await youtubeProbe(undefined), { configured: false });
  stubFetch([[/youtube/, 400, { error: { errors: [{ reason: "keyInvalid" }] } }]]);
  const bad = await youtubeProbe("SECRET-KEY");
  assertEquals(bad, { configured: true, ok: false, status: 400, reason: "keyInvalid", results: 0 });
  assert(!JSON.stringify(bad).includes("SECRET"));
  globalThis.fetch = realFetch;
});

Deno.test("instagram probe: the account first, then whether hashtag search is allowed", async () => {
  assertEquals(await instagramProbe(undefined, "1"), { configured: false, token: false, account_id: true });
  stubFetch([
    [/ig_hashtag_search/, 400, { error: { type: "OAuthException", code: 10 } }],
    [/graph\.facebook\.com\/v21\.0\/178/, 200, { username: "zad" }],
  ]);
  const r = await instagramProbe("TOKEN-SECRET", "178");
  assertEquals(r, { configured: true, account: { ok: true, status: 200 }, hashtag_search: { ok: false, status: 400, reason: "OAuthException/10" } });
  assert(!JSON.stringify(r).includes("TOKEN-SECRET"));
  // توكن منتهي: ميتا بترجع 400 وكود 190.
  stubFetch([[/graph/, 400, { error: { type: "OAuthException", code: 190 } }]]);
  assertEquals((await instagramProbe("t", "178")).account, { ok: false, status: 400, reason: "OAuthException/190" });
  globalThis.fetch = realFetch;
});
