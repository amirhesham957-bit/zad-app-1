import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { instagramRecipeHits, PLATFORM_NAME, recipePlatform, youtubeRecipeHits, youtubeRecipeQuery } from "./socialRecipeSources.ts";
import { readSocialVideo, socialVideoPrompt } from "./socialRecipes.ts";
import type { InstagramPost, YouTubeVideo } from "./socialSources.ts";

const yt = (id: string, title: string, description = ""): YouTubeVideo => ({
  id, title, channel: "مطبخ هالة", published_at: "2026-11-01T00:00:00Z", url: `https://www.youtube.com/watch?v=${id}`, description,
});
const ig = (code: string, caption: string): InstagramPost => ({
  id: code, caption, permalink: `https://www.instagram.com/reel/${code}/`, timestamp: "2026-11-01T00:00:00+0000", image_url: null,
});

Deno.test("an unknown platform is TikTok, as the scan was before", () => {
  assertEquals(recipePlatform("youtube"), "youtube");
  assertEquals(recipePlatform("instagram"), "instagram");
  assertEquals(recipePlatform(undefined), "tiktok");
  assertEquals(recipePlatform("facebook"), "tiktok");
  assertEquals(youtubeRecipeQuery("وصفات طبخ", "مصر"), "وصفات طبخ مصر");
});

Deno.test("YouTube: new videos with enough words, the channel as the source", () => {
  const videos = [
    yt("aaaaaaaaaaa", "طريقة عمل الكشري المصري", "المكونات: عدس، رز، مكرونة"),
    yt("aaaaaaaaaaa", "طريقة عمل الكشري المصري"),
    yt("bbbbbbbbbbb", "قصير"),
    yt("ccccccccccc", "محشي ورق عنب على أصوله", "ورق عنب، رز، طماطم"),
  ];
  const hits = youtubeRecipeHits(videos, new Set(["https://www.youtube.com/watch?v=ccccccccccc"]), "EG");
  assertEquals(hits.map((h) => h.url), ["https://www.youtube.com/watch?v=aaaaaaaaaaa"]);
  assertEquals(hits[0].handle, "مطبخ هالة");
  assertStringIncludes(hits[0].snippet, "عدس");
  assertEquals(youtubeRecipeHits(videos, new Set(), null, 1).length, 1);
});

Deno.test("Instagram: a caption long enough to hold a recipe, the account as the source", () => {
  const posts = [
    ig("AbC123", "شكشوكة في ١٠ دقايق\nالمكونات: بيض، طماطم، فلفل، بصل"),
    ig("Short1", "يمي 😋"),
    { ...ig("Bad", "رابط مش بوست ومكتوب فيه كلام كتير كفاية"), permalink: "https://example.com/x" },
  ];
  const hits = instagramRecipeHits(posts, "bashacook", new Set());
  assertEquals(hits.map((h) => h.url), ["https://www.instagram.com/reel/AbC123/"]);
  assertEquals(hits[0].title, "شكشوكة في ١٠ دقايق");
  assertEquals(hits[0].handle, "bashacook");
  assertEquals(instagramRecipeHits(posts, "bashacook", new Set(["https://www.instagram.com/reel/AbC123/"])), []);
});

Deno.test("the prompt names the platform, and the source's handle is kept", () => {
  const hit = { title: "كشري", url: "https://www.youtube.com/watch?v=aaaaaaaaaaa", snippet: "عدس رز" };
  assertStringIncludes(socialVideoPrompt(hit, "2026-11-10", PLATFORM_NAME.youtube).system, "فيديو يوتيوب عام");
  assertStringIncludes(socialVideoPrompt(hit, "2026-11-10").system, "فيديو تيك توك عام");
  const v = readSocialVideo({ recipe: { name: "كشري", ingredients: ["عدس", "رز"] } }, hit.url, new Date(), "مطبخ هالة");
  assertEquals(v.handle, "مطبخ هالة");
});
