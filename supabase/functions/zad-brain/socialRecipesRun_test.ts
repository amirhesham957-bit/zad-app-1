import { assertEquals } from "jsr:@std/assert@1";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { rotateForDay, runSocialRecipes, SOCIAL_SLOTS, socialRecipeRow, socialSources, videoCountry } from "./socialRecipesRun.ts";

Deno.test("every source lands in exactly one slot", () => {
  const all = [0, 1, 2].flatMap((s) => socialSources(s)).map((s) => JSON.stringify(s));
  assertEquals(new Set(all).size, all.length);
  // TikTok: 4 accounts + (3 topics + 3 hashtags) x 2 countries; YouTube: the 12 topics; Instagram: the 4 accounts.
  assertEquals(all.length, 32);
  assertEquals(socialSources(SOCIAL_SLOTS), socialSources(0));
  assertEquals(all.some((s) => s.includes("bashacook")), true);
  assertEquals(all.some((s) => s.includes("nadia.elsayed.official")), true);
  // Each country's trend hashtags are searched in that country only.
  assertEquals(all.some((s) => s.includes("#اكلات_مصرية") && s.includes('"EG"')), true);
  assertEquals(all.some((s) => s.includes("#اكلات_مصرية") && s.includes('"SA"')), false);
});

Deno.test("each slot reads all three platforms", () => {
  for (const slot of [0, 1, 2]) {
    const platforms = new Set(socialSources(slot).map((s) => s.platform));
    assertEquals([...platforms].sort(), ["instagram", "tiktok", "youtube"]);
  }
});

Deno.test("a slot starts somewhere else each day, and keeps every source", () => {
  assertEquals(rotateForDay([1, 2, 3], 0), [1, 2, 3]);
  assertEquals(rotateForDay([1, 2, 3], 1), [2, 3, 1]);
  assertEquals(rotateForDay([1, 2, 3], 5), [3, 1, 2]);
  assertEquals(rotateForDay([], 4), []);
});

const deal = (store: string) => ({ store, item_name: "زيت", price: 20, price_before: null, currency: "SAR", country: "SA", valid_until: null, source_url: "https://x" });

Deno.test("the country comes from the search, else from the deal's currency", () => {
  const v = { url: "u", handle: "h", recipe: null, stores: [], deals: [] };
  assertEquals(videoCountry({ topic: "x", country: "EG" }, v), "EG");
  assertEquals(videoCountry({ handle: "h", country: null }, v), null);
  assertEquals(videoCountry({ handle: "h", country: null }, { ...v, deals: [deal("x")] }), "SA");
});

Deno.test("a read video is stored, and only a known store's deal goes live", async () => {
  const upserts: Array<Record<string, unknown>> = [];
  const puts: unknown[] = [];
  const chain = (data: unknown) => {
    const c: Record<string, unknown> = { select: () => c, order: () => c, limit: () => Promise.resolve({ data }), in: () => Promise.resolve({ data }) };
    return c;
  };
  const sb = {
    from: (t: string) => t === "zad_social_recipes"
      ? { ...chain([{ source_url: "old" }]), upsert: (r: Record<string, unknown>) => { upserts.push(r); return Promise.resolve({ error: null }); } }
      : chain([{ country: "SA", store: "العثيم", currency: "SAR" }]),
    rpc: (_: string, a: unknown) => { puts.push(a); return Promise.resolve({ data: { ok: true }, error: null }); },
  } as unknown as SupabaseClient;
  let asked: Record<string, unknown> = {};
  const out = await runSocialRecipes(sb, 0, (p) => {
    asked = p;
    return Promise.resolve({ ok: true, videos: [{ url: "https://v", handle: "bashacook", recipe: { name: "كشري", ingredients: ["عدس", "رز"] }, stores: [], deals: [deal("العثيم"), deal("محل مجهول")] }] });
  }, new Date(0)); // day 0: no rotation, so the slot opens on a TikTok account
  assertEquals(asked.known, ["old"]);
  assertEquals(upserts[0].name, "كشري");
  assertEquals(upserts[0].country, "SA");
  assertEquals(puts.length, out.sources);
  assertEquals(out.refused, out.sources);
  // Each deal is filed under the platform it came from.
  const kinds = puts.map((p) => ((p as { p: { source_kind?: string } }).p).source_kind);
  assertEquals(new Set(kinds).size > 1, true);
});

// ZAD_PLAN ١٠.٩: اسم قناة يوتيوب أطول من ٤٠ كان بيكسر الصف كله (zad_social_recipes_handle_check)، والفيديو بيتقري تاني كل يوم.
Deno.test("a recipe row always fits the table: long channel names cut, odd recipe names dropped, not the row", () => {
  const source = { platform: "youtube" as const, topic: "محشي", country: "EG" };
  const video = (handle: string, name: string | null) => ({ url: "https://www.youtube.com/watch?v=1", handle, recipe: name === null ? null : { name, ingredients: ["رز"] }, stores: [], deals: [] });
  const long = socialRecipeRow(source, video("قناة مطبخ ".repeat(8), "محشي كرنب"));
  assertEquals((long.handle as string).length <= 40, true);
  assertEquals(long.name, "محشي كرنب");
  assertEquals(socialRecipeRow(source, video("  ", "x")).handle, "youtube");
  assertEquals(socialRecipeRow(source, video("a", "x")).name, null, "a one-letter name would break the name check");
  assertEquals((socialRecipeRow(source, video("a", "و".repeat(120))).name as string).length, 80);
  assertEquals(socialRecipeRow(source, video("a", null)).name, null);
});

Deno.test("a platform that brings nothing says why in the run summary", async () => {
  const chain = (data: unknown) => {
    const c: Record<string, unknown> = { select: () => c, order: () => c, limit: () => Promise.resolve({ data }), in: () => Promise.resolve({ data }) };
    return c;
  };
  const sb = { from: () => ({ ...chain([]), upsert: () => Promise.resolve({ error: null }) }), rpc: () => Promise.resolve({ data: null, error: null }) } as unknown as SupabaseClient;
  const out = await runSocialRecipes(sb, 0, (p) =>
    Promise.resolve(p.platform === "instagram" ? { ok: false, reason: "no_key" } as never : { ok: true, videos: [], search: p.platform === "tiktok" ? "google_news" : "youtube" } as never), new Date(0));
  assertEquals(Object.keys(out.empty).sort().filter((k) => k.startsWith("tiktok")), ["tiktok:search:google_news"]);
  assertEquals(out.empty["instagram:no_key"] > 0, true);
});
