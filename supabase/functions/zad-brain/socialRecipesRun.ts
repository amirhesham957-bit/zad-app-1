// كتابة وصفات وعروض تيك توك ويوتيوب وإنستجرام (ZAD_PLAN ٧.٤، المنصات الـ٣ ١٠/١١). القراية والفهم في zad-core-intelligence/socialRecipes.ts.
//
// الحسابات والمواضيع بتتوزع على ٣ نوبات (كرون social-recipes-daily)، والفيديو اللي اتقرا مايتعادش.
// عرض لمحل برّه قايمة zad_deal_seed_stores مابيدخلش zad_deals: الاسم جاي من وصف فيديو، والقايمة هي اللي بتثبت إنه محل حقيقي في بلده.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { RECIPE_ACCOUNTS, RECIPE_HASHTAGS, RECIPE_TOPICS, SOCIAL_COUNTRIES, type SocialVideo } from "../zad-core-intelligence/socialRecipes.ts";
import { dealPutPayload } from "./storeDeals.ts";
import { itemKey } from "./shared.ts";

export const SOCIAL_SLOTS = 3;
const RUN_BUDGET_MS = 110_000;

type Platform = "tiktok" | "youtube" | "instagram";
export type SocialSource =
  | { platform?: Platform; handle: string; country: null }
  | { platform?: Platform; topic: string; country: string };

/**
 * كل المصادر على المنصات الـ٣ (طلب المالك ١٠/١١)، متوزعة على النوبات. تيك توك: الحسابات والمواضيع بمحرك البحث؛ يوتيوب:
 * المواضيع في كل بلد؛ إنستجرام: نفس حسابات الشيفات (حساب مش Business بيترفض ويتساب). المنصات متداخلة عشان كل نوبة
 * فيها من التلاتة. نقي.
 */
export function socialSources(slot: number): SocialSource[] {
  const topics = Object.keys(SOCIAL_COUNTRIES).flatMap((country) =>
    [...RECIPE_TOPICS, ...(RECIPE_HASHTAGS[country] ?? [])].map((topic) => ({ topic, country }))
  );
  const lists: SocialSource[][] = [
    [...RECIPE_ACCOUNTS.map((handle) => ({ platform: "tiktok" as const, handle, country: null })), ...topics.map((t) => ({ platform: "tiktok" as const, ...t }))],
    topics.map((t) => ({ platform: "youtube" as const, ...t })),
    RECIPE_ACCOUNTS.map((handle) => ({ platform: "instagram" as const, handle, country: null })),
  ];
  // Each platform spreads over the slots on its own (offset by its index), then the slot's share is
  // interleaved: splitting one interleaved list by i % 3 put each platform in a single slot.
  const s = ((slot % SOCIAL_SLOTS) + SOCIAL_SLOTS) % SOCIAL_SLOTS;
  const mine = lists.map((list, li) => list.filter((_, j) => (j + li) % SOCIAL_SLOTS === s));
  const out: SocialSource[] = [];
  for (let i = 0; i < Math.max(...mine.map((l) => l.length)); i++) {
    for (const list of mine) if (i < list.length) out.push(list[i]);
  }
  return out;
}

/** النوبة بتبدأ من مكان مختلف كل يوم: المصادر اللي في آخرها مابتتقصّش دايماً لما الوقت يخلص. نقي. */
export function rotateForDay<T>(list: readonly T[], day: number): T[] {
  if (list.length === 0) return [];
  const k = ((day % list.length) + list.length) % list.length;
  return [...list.slice(k), ...list.slice(0, k)];
}

/** بلد الفيديو: من المصدر لو بحث عام، وإلا من عملة عروضه. مش معروف = null (الوصفة تنفع أي بلد). */
export function videoCountry(source: SocialSource, video: SocialVideo): string | null {
  return source.country ?? video.deals[0]?.country ?? null;
}

/**
 * الصف اللي بيتكتب في zad_social_recipes على قد قيود الجدول (handle ١–٤٠، name ٢–٨٠). اسم قناة يوتيوب أطول من ٤٠ كان
 * بيكسر الصف كله (`zad_social_recipes_handle_check`، مرة في اليوم ١٢–١٣/١١)، والفيديو مايتسجلش «اتقرا» فبيتقري تاني كل
 * يوم (ZAD_PLAN ١٠.٩). اسم وصفة برّه الحدود بيبقى null (الصف بيتسجل إنه اتقرا، والشيف مابيعرضهوش). نقي.
 */
export function socialRecipeRow(source: SocialSource, video: SocialVideo): Record<string, unknown> {
  const oneLine = (v: unknown) => typeof v === "string" ? v.replace(/\s+/g, " ").trim() : "";
  const handle = oneLine(video.handle).slice(0, 40) || (source.platform ?? "tiktok");
  const name = oneLine(video.recipe?.name).slice(0, 80);
  return {
    source_url: video.url, handle, country: videoCountry(source, video),
    name: name.length >= 2 ? name : null, ingredients: video.recipe?.ingredients ?? [], stores: video.stores,
  };
}

export async function runSocialRecipes(
  sb: SupabaseClient, slot: number, scan: (payload: Record<string, unknown>) => Promise<{ ok?: boolean; videos?: SocialVideo[] } | null>,
  now: Date = new Date(),
): Promise<{ ok: boolean; sources: number; videos: number; recipes: number; deals: number; refused: number; empty: Record<string, number> }> {
  const started = Date.now();
  // «empty» = المنصة رجّعت صفر فيديو وليه (no_key، youtube_403، search:none…). تيك توك وقف يومين ١١–١٣/١١ (البحث
  // المجاني خلص ووقع على أخبار جوجل) والملخص كان بيقول ok:true من غير ما حد يعرف.
  const totals = { ok: true, sources: 0, videos: 0, recipes: 0, deals: 0, refused: 0, empty: {} as Record<string, number> };
  const [{ data: knownRows }, { data: storeRows }] = await Promise.all([
    sb.from("zad_social_recipes").select("source_url").order("found_at", { ascending: false }).limit(1000),
    sb.from("zad_deal_seed_stores").select("country,store,currency").in("country", Object.keys(SOCIAL_COUNTRIES)),
  ]);
  const known = ((knownRows ?? []) as Array<{ source_url: string }>).map((r) => r.source_url);
  const stores = (storeRows ?? []) as Array<{ country: string; store: string; currency: string }>;
  for (const source of rotateForDay(socialSources(slot), Math.floor(now.getTime() / 86_400_000))) {
    if (Date.now() - started > RUN_BUDGET_MS) break;
    const reply = await scan({ ...source, known });
    totals.sources++;
    if (!reply?.videos?.length) {
      const why = `${source.platform ?? "tiktok"}:${reply?.ok === false ? String((reply as { reason?: unknown }).reason ?? "failed") : reply ? `search:${String((reply as { search?: unknown }).search ?? "none")}` : "no_reply"}`.slice(0, 60);
      totals.empty[why] = (totals.empty[why] ?? 0) + 1;
    }
    for (const video of reply?.videos ?? []) {
      totals.videos++;
      // بيتسجل حتى لو مش وصفة: عشان مايتقريش تاني.
      const { error } = await sb.from("zad_social_recipes").upsert(socialRecipeRow(source, video), { onConflict: "source_url" });
      if (error) console.error("[social_recipes] write failed:", error.message);
      else if (video.recipe) totals.recipes++;
      for (const deal of video.deals) {
        const target = stores.find((s) => s.country === deal.country && itemKey(s.store) === itemKey(deal.store));
        if (!target) {
          totals.refused++;
          continue;
        }
        const { data, error: putErr } = await sb.rpc("zad_deal_put", {
          p: dealPutPayload({ country: target.country, store: target.store, currency: target.currency }, deal, source.platform ?? "tiktok"),
        });
        if (!putErr && (data as { ok?: boolean } | null)?.ok) totals.deals++;
        else totals.refused++;
      }
    }
  }
  return totals;
}
