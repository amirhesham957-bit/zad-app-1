// يوتيوب وإنستجرام (ZAD_PLAN ٤.١١، ٤.١٢): الفحص بيقول السبب ومابيطلّعش المفتاح.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { instagramHashtagPosts, instagramProbe, storeHashtag, youtubeProbe, youtubeSearch } from "./socialSources.ts";

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

Deno.test("instagram posts: the store's hashtag, the last days only, links and pictures kept", async () => {
  const seen = stubFetch([
    [/ig_hashtag_search/, 200, { data: [{ id: "17841" }] }],
    [/top_media/, 200, {
      data: [
        { id: "1", caption: "عروض كارفور: زيت ٨٥ بدل ٩٩", permalink: "https://www.instagram.com/p/AbC1/", timestamp: "2026-11-02T10:00:00+0000", media_type: "IMAGE", media_url: "https://scontent.cdninstagram.com/a.jpg" },
        { id: "2", caption: "قديم", permalink: "https://www.instagram.com/p/Old/", timestamp: "2026-10-01T10:00:00+0000", media_type: "IMAGE", media_url: "https://x/b.jpg" },
        { id: "3", caption: "ريل", permalink: "https://www.instagram.com/reel/Rr9/", timestamp: "2026-11-01T10:00:00+0000", media_type: "VIDEO", media_url: "https://x/v.mp4" },
        { id: "4", caption: "رابط غريب", permalink: "https://evil.example/p/1/", timestamp: "2026-11-02T10:00:00+0000", media_type: "IMAGE" },
      ],
    }],
  ]);
  const r = await instagramHashtagPosts("TOKEN", "999", storeHashtag("كارفور"), { now: Date.parse("2026-11-03T00:00:00Z") });
  assert(r.ok);
  assertEquals(r.items.map((p) => [p.id, p.image_url !== null]), [["1", true], ["3", false]]);
  assert(decodeURIComponent(seen[0]).includes("q=عروض_كارفور"));
  assert(seen[1].includes("17841/top_media"));
  globalThis.fetch = realFetch;
});

Deno.test("instagram posts: Meta's refusal comes back as a reason, never the token", async () => {
  stubFetch([[/ig_hashtag_search/, 400, { error: { type: "OAuthException", code: 190 } }]]);
  const r = await instagramHashtagPosts("SECRET-TOKEN", "999", "عروض_كيو");
  assertEquals([r.ok, r.status, r.reason], [false, 400, "OAuthException/190"]);
  assert(!JSON.stringify(r).includes("SECRET"));
  globalThis.fetch = realFetch;
});

Deno.test("store hashtag: no spaces or marks", () => {
  assertEquals(storeHashtag("هايبر وان"), "عروض_هايبر_وان");
  assertEquals(storeHashtag("Spinneys!"), "عروض_Spinneys");
});
