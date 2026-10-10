// سعر دوا (medicinePrice.ts، الموجة ٤): كاش ٣٠ يوم، بحث موجّه ببلده وعملته، ومفيش رقم من غير مصدر.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { medicineKey, medicinePrice, medicinePriceReply, priceFromEstimate } from "./medicinePrice.ts";
import { intentToolHints, scopeToolsForSpecialist } from "./specialists.ts";
import { freshContext, MUTATING_TOOLS, VALIDATORS } from "./validators.ts";
import { CHAT_TOOLS } from "./index.ts";

const NOW = Date.parse("2026-10-11T10:00:00Z");
const OK = {
  status: "ok", low_price: 60, high_price: 75.456, currency: "جنيه",
  sources: [{ title: "صيدلية", url: "https://example.com/p" }, { title: "بلا رابط" }, { title: "x", url: "javascript:1" }],
};

Deno.test("price: only a number with a source is kept; the customer's currency wins", () => {
  const p = priceFromEstimate("بنادول إكسترا", OK, "EGP", NOW)!;
  assertEquals([p.low, p.high, p.currency, p.sources.length, p.from], [60, 75.46, "EGP", 1, "search"]);
  assertEquals(priceFromEstimate("x", { ...OK, sources: [] }, "EGP", NOW), null);
  assertEquals(priceFromEstimate("x", { status: "unclear" }, "EGP", NOW), null);
  assertEquals(priceFromEstimate("x", { ...OK, low_price: 0 }, "EGP", NOW), null);
  assertEquals(priceFromEstimate("x", { ...OK, high_price: 10 }, "EGP", NOW), null);
  assertEquals(medicineKey("  أوجمنتين   ١جم "), medicineKey("اوجمنتين ١جم"));
});

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

Deno.test("price: a fresh saved price answers with no search; an old one searches in the customer's market", async () => {
  let searched: Record<string, unknown> | null = null;
  const search = (payload: Record<string, unknown>) => { searched = payload; return Promise.resolve(OK); };
  const saved = { name: "بنادول إكسترا", price_low: 60, price_high: 70, currency: "EGP", sources: [{ title: "a", url: "https://a" }] };
  const fresh = cacheSb({ ...saved, found_at: new Date(NOW - 10 * 86_400_000).toISOString() });
  const hit = await medicinePrice(fresh.sb, { name: "بنادول إكسترا", country: "eg", currency: "EGP", now: NOW, search });
  assertEquals([hit?.from, searched], ["cache", null]);
  assert(fresh.filters.some(([c, v]) => c === "country" && v === "EG"));

  const old = cacheSb({ ...saved, found_at: new Date(NOW - 31 * 86_400_000).toISOString() });
  const again = await medicinePrice(old.sb, { name: "بنادول إكسترا", country: "EG", currency: "EGP", now: NOW, search });
  assertEquals(again?.from, "search");
  assertEquals(searched, { item_name: "دواء بنادول إكسترا", store: "صيدلية", location: "مصر", currency: "EGP" });
  assertEquals([old.writes.length, old.writes[0].country, old.writes[0].price_low], [1, "EG", 60]);
});

Deno.test("price: nothing found is said plainly, never saved; no country, no search", async () => {
  const none = cacheSb(null);
  assertEquals(await medicinePrice(none.sb, { name: "دوا", country: "EG", currency: "EGP", now: NOW, search: () => Promise.resolve({ status: "no_results" }) }), null);
  assertEquals(none.writes.length, 0);
  let called = false;
  assertEquals(await medicinePrice(cacheSb(null).sb, { name: "دوا", country: null, currency: null, now: NOW, search: () => { called = true; return Promise.resolve(OK); } }), null);
  assertEquals(called, false);
  assertEquals(await medicinePrice(cacheSb(null).sb, { name: "دوا", country: "EG", currency: "EGP", now: NOW, search: () => Promise.reject(new Error("down")) }), null);
  assertStringIncludes(medicinePriceReply(null, "دوا"), "ماتقولش رقم من عندك");
  const reply = JSON.parse(medicinePriceReply(priceFromEstimate("بنادول", OK, "EGP", NOW), "بنادول"));
  assertEquals([reply.price, reply.currency, reply.found_on], ["60–75.46", "EGP", "2026-10-11"]);
  assertStringIncludes(reply.note, "من غير أي نصيحة طبية");
});

Deno.test("price: «بكام» about a medicine brings the tool, in the pharmacy specialist too", () => {
  for (const ask of ["البنادول بكام دلوقتي؟", "سعر دوا الضغط كام", "شريط المضاد بكام"]) assert(intentToolHints(ask).includes("medicine_price"), ask);
  for (const other of ["العيش بكام", "عامل ايه"]) assert(!intentToolHints(other).includes("medicine_price"), other);
  assert(scopeToolsForSpecialist(CHAT_TOOLS, "pharmacy").some((t) => t.name === "medicine_price"));
  assert(!MUTATING_TOOLS.includes("medicine_price"));
  const ctx = freshContext("u");
  assertEquals((VALIDATORS.medicine_price({ name: "x" }, {}, ctx) as { ok: boolean }).ok, false);
  assertEquals(VALIDATORS.medicine_price({ name: "بنادول" }, {}, ctx), { ok: true });
  ctx.counts.medicine_price = 2;
  assertEquals((VALIDATORS.medicine_price({ name: "بنادول" }, {}, ctx) as { ok: boolean }).ok, false);
});
