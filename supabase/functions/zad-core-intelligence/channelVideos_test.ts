import { assert, assertEquals } from "jsr:@std/assert@1";
import { _resetChannelCachesForTest, CHANNELS, channelsFor, channelVideos, type ChannelVideo, HANDLE_RE, pickVideos } from "./channelVideos.ts";

const NOW = Date.parse("2026-11-22T12:00:00Z");
const v = (id: string, at: string, title = "فيديو"): ChannelVideo => ({
  id, title, channel: "c", handle: "h", kind: "chef", published_at: at, url: `https://www.youtube.com/watch?v=${id}`, thumbnail: null,
});

Deno.test("every curated handle is well formed and unique within its country", () => {
  for (const [cc, list] of Object.entries(CHANNELS)) {
    assertEquals(cc, cc.toUpperCase());
    assertEquals(new Set(list.map((c) => c.handle.toLowerCase())).size, list.length);
    for (const c of list) assert(HANDLE_RE.test(c.handle), `${cc}/${c.handle}`);
  }
  assertEquals(channelsFor("zz"), []);
  assert(channelsFor("eg").length > 0);
});

Deno.test("pickVideos: newest first, deduped, stale and removed ones dropped (mutation-style)", () => {
  const input = [
    v("old00000", "2026-10-01T00:00:00Z"),
    v("aaaaaa", "2026-11-20T00:00:00Z"),
    v("bbbbbb", "2026-11-21T00:00:00Z"),
    v("aaaaaa", "2026-11-20T00:00:00Z"),
    v("priv00", "2026-11-21T00:00:00Z", "Private video"),
    v("del000", "2026-11-21T00:00:00Z", "Deleted video"),
    v("future", "2027-01-01T00:00:00Z"),
    v("nodate", ""),
  ];
  assertEquals(pickVideos(input, 10, 14, NOW).map((x) => x.id), ["bbbbbb", "aaaaaa"]);
  // Reversing the input must not change the answer: kills a mutant that removes the sort.
  assertEquals(pickVideos([...input].reverse(), 10, 14, NOW).map((x) => x.id), ["bbbbbb", "aaaaaa"]);
  assertEquals(pickVideos(input, 1, 14, NOW).length, 1);
  // A wider window brings the old one back: kills a mutant that ignores `days`.
  assertEquals(pickVideos(input, 10, 90, NOW).map((x) => x.id), ["bbbbbb", "aaaaaa", "old00000"]);
});

function stub(log: string[], fail = false) {
  return (url: string): Promise<Response> => {
    log.push(url);
    if (fail) return Promise.resolve(new Response("{}", { status: 403 }));
    const u = new URL(url);
    if (u.pathname.endsWith("/channels")) {
      return Promise.resolve(Response.json({ items: [{ contentDetails: { relatedPlaylists: { uploads: "UUabcdefghijk" } } }] }));
    }
    return Promise.resolve(Response.json({ items: [
      { snippet: { title: "كشري", channelTitle: "قناة", publishedAt: "2026-11-21T00:00:00Z", resourceId: { videoId: "vid12345" }, thumbnails: { medium: { url: "https://i.ytimg.com/x.jpg" } } } },
      { snippet: { title: "بدون id", publishedAt: "2026-11-21T00:00:00Z", resourceId: {} } },
    ] }));
  };
}

Deno.test("channelVideos: reads uploads per handle, never leaks the key, caches the country", async () => {
  _resetChannelCachesForTest();
  const log: string[] = [];
  const r = await channelVideos("SECRETKEY", "AE", { fetcher: stub(log), now: NOW });
  assert(r.ok);
  assertEquals(r.videos.length, 1);
  assertEquals(r.videos[0].url, "https://www.youtube.com/watch?v=vid12345");
  assertEquals(r.videos[0].thumbnail, "https://i.ytimg.com/x.jpg");
  assert(!JSON.stringify(r).includes("SECRETKEY"));
  assertEquals(log.length, channelsFor("AE").length * 2);
  await channelVideos("SECRETKEY", "AE", { fetcher: stub(log), now: NOW + 1000 });
  assertEquals(log.length, channelsFor("AE").length * 2, "second call served from cache");
});

Deno.test("channelVideos: no key, unknown country, and total failure are told apart", async () => {
  _resetChannelCachesForTest();
  assertEquals((await channelVideos(undefined, "EG")).reason, "no_key");
  assertEquals(await channelVideos("k", "ZZ", { fetcher: stub([]) }), { ok: true, videos: [] });
  const failed = await channelVideos("k", "EG", { fetcher: stub([], true), now: NOW });
  assert(!failed.ok);
  assertEquals(failed.reason, "youtube_403");
});

Deno.test("channelVideos: the kind filter only asks the matching channels", async () => {
  _resetChannelCachesForTest();
  const log: string[] = [];
  await channelVideos("k", "SA", { fetcher: stub(log), now: NOW, kind: "chef" });
  assertEquals(log.length, channelsFor("SA").filter((c) => c.kind === "chef").length * 2);
});
