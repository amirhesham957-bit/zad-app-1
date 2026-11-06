import { assertEquals } from "jsr:@std/assert@1";
import { type HomeDealCard, withPagePreviews } from "./seasonDigest.ts";

const NOW = Date.parse("2026-11-06T10:00:00Z");

function fakeSb(rows: Array<{ url: string; image: string | null; checked_at: string }>) {
  const upserts: unknown[] = [];
  const sb = {
    from: (_t: string) => ({
      select: () => ({ in: (_c: string, urls: string[]) => Promise.resolve({ data: rows.filter((r) => urls.includes(r.url)) }) }),
      upsert: (r: unknown) => { upserts.push(...(r as unknown[])); return Promise.resolve({ error: null }); },
    }),
  };
  return { sb: sb as never, upserts };
}

const card = (url: string | null, photo: string | null = null) =>
  ({ key: url ?? "k", item: "زيت", store: "بيم", price: 50, price_before: null, currency: "EGP", saving: null, why: "need", url, source: "search", photo, until: null, codes: [] }) as unknown as HomeDealCard;

Deno.test("a cached picture is used, a new page is read once and stored", async () => {
  const { sb, upserts } = fakeSb([{ url: "https://a.com/1", image: "https://a.com/1.jpg", checked_at: "2026-11-05T00:00:00Z" }]);
  const read: string[] = [];
  const out = await withPagePreviews(sb, [card("https://a.com/1"), card("https://b.com/2")], [], async (u) => { read.push(u); return "https://b.com/2.jpg"; }, NOW);
  assertEquals(out.map((c) => c.photo), ["https://a.com/1.jpg", "https://b.com/2.jpg"]);
  assertEquals(read, ["https://b.com/2"]);
  assertEquals((upserts[0] as { url: string }).url, "https://b.com/2");
});

Deno.test("a page checked lately without a picture is not read again", async () => {
  const { sb } = fakeSb([{ url: "https://a.com/1", image: null, checked_at: "2026-11-04T00:00:00Z" }]);
  const read: string[] = [];
  const out = await withPagePreviews(sb, [card("https://a.com/1")], [], async (u) => { read.push(u); return null; }, NOW);
  assertEquals(read, []);
  assertEquals(out[0].photo, null);
});

Deno.test("YouTube cards keep their thumbnail and Amazon pages are never read", async () => {
  const { sb } = fakeSb([]);
  const read: string[] = [];
  const out = await withPagePreviews(sb, [card("https://www.youtube.com/watch?v=abcdefg", "https://i.ytimg.com/x.jpg"), card("https://www.amazon.sa/dp/B07F2XB1V5")], [], async (u) => { read.push(u); return "x"; }, NOW);
  assertEquals(read, []);
  assertEquals(out.map((c) => c.photo), ["https://i.ytimg.com/x.jpg", null]);
});
