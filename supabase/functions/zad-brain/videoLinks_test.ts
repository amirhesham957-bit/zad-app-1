import { assertEquals } from "jsr:@std/assert@1";
import { videoAlive, videosForChat, youtubeAlternative } from "./videoLinks.ts";

const LIVE = "https://www.youtube.com/watch?v=aaaaaaaaaaa";
const DEAD = "https://www.youtube.com/watch?v=bbbbbbbbbbb";
const FOUND = "https://www.youtube.com/watch?v=ccccccccccc";

/** oEmbed answers 200 for [live] videos only; the search returns [results]. */
function fakeFetch(live: string[], results: string[] = [], calls: string[] = []): typeof fetch {
  return ((input: string | URL | Request) => {
    const url = String(input);
    calls.push(url);
    if (url.includes("/oembed")) {
      const target = decodeURIComponent(url.split("url=")[1] ?? "");
      return Promise.resolve(new Response("{}", { status: live.includes(target) ? 200 : 404 }));
    }
    if (url.includes("youtube/v3/search")) {
      return Promise.resolve(new Response(JSON.stringify({ items: results.map((id) => ({ id: { videoId: id } })) }), { status: 200 }));
    }
    return Promise.resolve(new Response("", { status: 500 }));
  }) as typeof fetch;
}
const withKey = (k: string) => (k === "YOUTUBE_API_KEY" ? "test-key" : undefined);
const noKey = (_: string) => undefined;

Deno.test("a live YouTube link stays as it is", async () => {
  const reply = `شوف الطريقة هنا: ${LIVE}`;
  assertEquals(await videosForChat(reply, { fetcher: fakeFetch([LIVE]), env: noKey }), reply);
});

Deno.test("a dead YouTube link is replaced by the first live result, searched by its line", async () => {
  const calls: string[] = [];
  const reply = `🎥 طريقة الكشري المصري: ${DEAD}`;
  const out = await videosForChat(reply, { fetcher: fakeFetch([FOUND], ["bbbbbbbbbbb", "ccccccccccc"], calls), env: withKey });
  assertEquals(out, `🎥 طريقة الكشري المصري: ${FOUND}`);
  const search = calls.find((c) => c.includes("youtube/v3/search"))!;
  assertEquals(new URL(search).searchParams.get("q"), "طريقة الكشري المصري");
});

Deno.test("a dead YouTube link with no key or no alternative is dropped, the words stay", async () => {
  const out = await videosForChat(`طريقة الكشري: ${DEAD}`, { fetcher: fakeFetch([]), env: noKey });
  assertEquals(out, "طريقة الكشري");
  const none = await videosForChat(`طريقة الكشري: ${DEAD}`, { fetcher: fakeFetch([], []), env: withKey });
  assertEquals(none, "طريقة الكشري");
});

Deno.test("TikTok is checked by its oEmbed; Instagram links the model wrote are dropped", async () => {
  const tt = "https://www.tiktok.com/@bashacook/video/7300000000000000001";
  const deadTt = "https://www.tiktok.com/@bashacook/video/7300000000000000002";
  const ig = "https://www.instagram.com/reel/AbCdEf123/";
  const reply = `فيديو: ${tt}\nتاني: ${deadTt}\nريل: ${ig}`;
  const out = await videosForChat(reply, { fetcher: fakeFetch([tt]), env: noKey });
  assertEquals(out, `فيديو: ${tt}\nتاني\nريل`);
});

Deno.test("no video links: no network at all", async () => {
  const calls: string[] = [];
  const reply = "اعمل كشري بالعدس والرز";
  assertEquals(await videosForChat(reply, { fetcher: fakeFetch([], [], calls), env: withKey }), reply);
  assertEquals(calls.length, 0);
});

Deno.test("videoAlive and youtubeAlternative fail closed", async () => {
  const boom = (() => Promise.reject(new Error("offline"))) as typeof fetch;
  assertEquals(await videoAlive(LIVE, boom), false);
  assertEquals(await youtubeAlternative("كشري", { fetcher: boom, env: withKey }), null);
  assertEquals(await youtubeAlternative("كشري", { fetcher: fakeFetch([FOUND], ["ccccccccccc"]), env: noKey }), null);
});
