/**
 * وصفات من يوتيوب وإنستجرام جنب تيك توك (طلب المالك ١٠/١١: «الـ٣ منصات»). نفس فكرة socialRecipes.ts: اللي بيتاخد
 * اسم الأكلة ومكوناتها المكتوبين ورابط الفيديو، ومفيش تنزيل فيديو ولا كشط.
 *
 *   يوتيوب ⇐ YouTube Data API (YOUTUBE_API_KEY): بحث بموضوع الوصفات في كل بلد، والعنوان والوصف هما النص.
 *   إنستجرام ⇐ Graph API business_discovery على حسابات الشيفات: الكابشن هو النص (غالباً فيه المكونات كاملة).
 *               حساب مش Business/Creator بيرجع رفض من Meta وبيتساب.
 */

import type { DealHit } from "./liveDeals.ts";
import { namesOtherCountry } from "./liveDeals.ts";
import type { InstagramPost, YouTubeVideo } from "./socialSources.ts";

export type RecipePlatform = "tiktok" | "youtube" | "instagram";

/** اسم المنصة جوه البرومبت. */
export const PLATFORM_NAME: Readonly<Record<RecipePlatform, string>> = {
  tiktok: "تيك توك", youtube: "يوتيوب", instagram: "إنستجرام",
};

/** أي قيمة مش معروفة = تيك توك، زي ما الفحص كان قبل كده. */
export function recipePlatform(v: unknown): RecipePlatform {
  return v === "youtube" || v === "instagram" ? v : "tiktok";
}

export function youtubeRecipeQuery(topic: string, countryName: string): string {
  return `${topic} ${countryName}`;
}

/** فيديو يتقري ومعاه صاحبه (القناة أو الحساب). */
export type RecipeHit = DealHit & { handle: string };

const YOUTUBE_WATCH = /^https:\/\/www\.youtube\.com\/watch\?v=[\w-]{11}$/;
const INSTAGRAM_POST = /^https:\/\/(?:www\.)?instagram\.com\/(?:reels?|p|tv)\/[\w-]+\/?$/;

/** فيديوهات يوتيوب تستاهل تتقري: مش اتقريت، وفيها كلام كفاية، ومش لبلد تاني. كل واحدة نداء جيميناي. */
export function youtubeRecipeHits(
  videos: readonly YouTubeVideo[], known: ReadonlySet<string>, country: string | null, max = 3,
): RecipeHit[] {
  const out: RecipeHit[] = [];
  for (const v of videos) {
    if (!YOUTUBE_WATCH.test(v.url) || known.has(v.url) || out.some((h) => h.url === v.url)) continue;
    const text = `${v.title} ${v.description ?? ""}`;
    if (text.trim().length < 12 || (country && namesOtherCountry(text, country))) continue;
    out.push({ title: v.title.slice(0, 200), url: v.url, snippet: (v.description ?? "").slice(0, 1200), handle: v.channel.slice(0, 60) });
    if (out.length >= max) break;
  }
  return out;
}

/** بوستات إنستجرام بكابشن يتقري. الكابشن هو العنوان والوصف. */
export function instagramRecipeHits(
  posts: readonly InstagramPost[], handle: string, known: ReadonlySet<string>, max = 3,
): RecipeHit[] {
  const out: RecipeHit[] = [];
  for (const p of posts) {
    const url = p.permalink.trim();
    if (!INSTAGRAM_POST.test(url) || known.has(url) || out.some((h) => h.url === url)) continue;
    const caption = p.caption.trim();
    if (caption.length < 20) continue;
    out.push({ title: caption.split("\n")[0].slice(0, 200), url, snippet: caption.slice(0, 1200), handle });
    if (out.length >= max) break;
  }
  return out;
}
