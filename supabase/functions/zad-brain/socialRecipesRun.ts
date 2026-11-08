// كتابة وصفات وعروض تيك توك (ZAD_PLAN ٧.٤). القراية والفهم في zad-core-intelligence/socialRecipes.ts.
//
// الحسابات والمواضيع بتتوزع على ٣ نوبات (كرون social-recipes-twice-weekly)، والفيديو اللي اتقرا مايتعادش.
// عرض لمحل برّه قايمة zad_deal_seed_stores مابيدخلش zad_deals: الاسم جاي من وصف فيديو، والقايمة هي اللي بتثبت إنه محل حقيقي في بلده.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { RECIPE_ACCOUNTS, RECIPE_TOPICS, SOCIAL_COUNTRIES, type SocialVideo } from "../zad-core-intelligence/socialRecipes.ts";
import { dealPutPayload } from "./storeDeals.ts";
import { itemKey } from "./shared.ts";

export const SOCIAL_SLOTS = 3;
const RUN_BUDGET_MS = 110_000;

export type SocialSource = { handle: string; country: null } | { topic: string; country: string };

/** كل المصادر، ومقسومة على النوبات. نقي. */
export function socialSources(slot: number): SocialSource[] {
  const all: SocialSource[] = [
    ...RECIPE_ACCOUNTS.map((handle) => ({ handle, country: null })),
    ...Object.keys(SOCIAL_COUNTRIES).flatMap((country) => RECIPE_TOPICS.map((topic) => ({ topic, country }))),
  ];
  const s = ((slot % SOCIAL_SLOTS) + SOCIAL_SLOTS) % SOCIAL_SLOTS;
  return all.filter((_, i) => i % SOCIAL_SLOTS === s);
}

/** بلد الفيديو: من المصدر لو بحث عام، وإلا من عملة عروضه. مش معروف = null (الوصفة تنفع أي بلد). */
export function videoCountry(source: SocialSource, video: SocialVideo): string | null {
  return source.country ?? video.deals[0]?.country ?? null;
}

export async function runSocialRecipes(
  sb: SupabaseClient, slot: number, scan: (payload: Record<string, unknown>) => Promise<{ ok?: boolean; videos?: SocialVideo[] } | null>,
): Promise<{ ok: boolean; sources: number; videos: number; recipes: number; deals: number; refused: number }> {
  const started = Date.now();
  const totals = { ok: true, sources: 0, videos: 0, recipes: 0, deals: 0, refused: 0 };
  const [{ data: knownRows }, { data: storeRows }] = await Promise.all([
    sb.from("zad_social_recipes").select("source_url").order("found_at", { ascending: false }).limit(1000),
    sb.from("zad_deal_seed_stores").select("country,store,currency").in("country", Object.keys(SOCIAL_COUNTRIES)),
  ]);
  const known = ((knownRows ?? []) as Array<{ source_url: string }>).map((r) => r.source_url);
  const stores = (storeRows ?? []) as Array<{ country: string; store: string; currency: string }>;
  for (const source of socialSources(slot)) {
    if (Date.now() - started > RUN_BUDGET_MS) break;
    const reply = await scan({ ...source, known });
    totals.sources++;
    for (const video of reply?.videos ?? []) {
      totals.videos++;
      // بيتسجل حتى لو مش وصفة: عشان مايتقريش تاني.
      const { error } = await sb.from("zad_social_recipes").upsert({
        source_url: video.url, handle: video.handle, country: videoCountry(source, video),
        name: video.recipe?.name ?? null, ingredients: video.recipe?.ingredients ?? [], stores: video.stores,
      }, { onConflict: "source_url" });
      if (error) console.error("[social_recipes] write failed:", error.message);
      else if (video.recipe) totals.recipes++;
      for (const deal of video.deals) {
        const target = stores.find((s) => s.country === deal.country && itemKey(s.store) === itemKey(deal.store));
        if (!target) {
          totals.refused++;
          continue;
        }
        const { data, error: putErr } = await sb.rpc("zad_deal_put", {
          p: dealPutPayload({ country: target.country, store: target.store, currency: target.currency }, deal, "tiktok"),
        });
        if (!putErr && (data as { ok?: boolean } | null)?.ok) totals.deals++;
        else totals.refused++;
      }
    }
  }
  return totals;
}
