// check_price_online (webPrice.ts): a sourced price is kept 7 days per country and item; none without a source.
import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { webPrice, webPriceKey, webPriceReply } from "./webPrice.ts";

const NOW = Date.parse("2026-10-11T12:00:00Z");
const OK = { status: "ok", low_price: 30, high_price: 34, currency: "EGP", sources: [{ title: "جهينة", url: "https://example.com/milk" }] };

function cacheSb(row: Record<string, unknown> | null) {
  const writes: Array<Record<string, unknown>> = [];
  const filters: Array<[string, unknown]> = [];
  const sb = {
    from: () => {
      const q = {
        select: () => q,
        eq: (c: string, v: unknown) => { filters.push([c, v]); return q; },
        maybeSingle: () => Promise.resolve({ data: row, error: null }),
        upsert: (r: Record<string, unknown>) => { writes.push(r); return Promise.resolve({ error: null }); },
      };
      return q;
    },
  } as unknown as SupabaseClient;
  return { sb, writes, filters };
}

Deno.test("a fresh saved price answers with no search; an old one searches in the customer's market and is kept", async () => {
  let searched: Record<string, unknown> | null = null;
  const search = (p: Record<string, unknown>) => { searched = p; return Promise.resolve(OK); };
  const saved = { name: "لبن", store: null, price_low: 29, price_high: 31, currency: "EGP", sources: [{ title: "a", url: "https://a" }] };

  const fresh = cacheSb({ ...saved, found_at: new Date(NOW - 3 * 86_400_000).toISOString() });
  const hit = await webPrice(fresh.sb, { item: "لبن", country: "eg", currency: "EGP", now: NOW, search });
  assertEquals([hit?.from, hit?.low, searched], ["cache", 29, null]);
  assertEquals(fresh.filters, [["country", "EG"], ["name_key", webPriceKey("لبن", null)]]);

  const old = cacheSb({ ...saved, found_at: new Date(NOW - 8 * 86_400_000).toISOString() });
  const again = await webPrice(old.sb, { item: "لبن", store: "كارفور", country: "EG", currency: "EGP", now: NOW, search });
  assertEquals(again?.from, "search");
  assertEquals((searched as Record<string, unknown> | null)?.location, "مصر");
  assertEquals((searched as Record<string, unknown> | null)?.store, "كارفور");
  assertEquals(old.writes[0].name_key, webPriceKey("لبن", "كارفور"));
  assertEquals(old.writes[0].country, "EG");
});

Deno.test("no source, no number — and nothing kept", async () => {
  const none = cacheSb(null);
  const out = await webPrice(none.sb, {
    item: "لبن", country: "EG", currency: "EGP", now: NOW,
    search: () => Promise.resolve({ ...OK, sources: [] }),
  });
  assertEquals([out, none.writes.length], [null, 0]);
  assertStringIncludes(webPriceReply(null, "لبن"), "متقولش رقم");
});

Deno.test("the reply says it is a web search, with its source and date", () => {
  const reply = webPriceReply({ name: "لبن", store: null, low: 30, high: 34, currency: "EGP", sources: OK.sources, found_at: "2026-10-11T12:00:00Z", from: "search" }, "لبن");
  assertStringIncludes(reply, "بحث نت دلوقتي");
  assertStringIncludes(reply, "https://example.com/milk");
  assertStringIncludes(reply, "مش من فواتير");
});
