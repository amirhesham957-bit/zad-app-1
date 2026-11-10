// روابط الفيديو في رد الشات (بلاغ المالك ١٠/١١): الموديل بيكتب روابط يوتيوب من دماغه، والعميل بيفتح «This video is
// unavailable». قبل ما الرد يتبعت كل رابط فيديو بيتفحص بالطريق الرسمي المجاني:
//   يوتيوب ⇐ youtube.com/oembed (٢٠٠ = الفيديو موجود وعام). مكسور ⇐ أول بديل شغال من YouTube Data API
//            (YOUTUBE_API_KEY) بكلام السطر اللي كان فيه، ومفحوص بنفس الطريقة. مفيش مفتاح أو مفيش بديل ⇐ الرابط بيتشال.
//   تيك توك ⇐ tiktok.com/oembed (٢٠٠ = موجود). مكسور ⇐ بيتشال.
//   إنستجرام ⇐ مفيش فحص من غير توكن Meta، فرابط كتبه الموديل بيتشال. روابط إنستجرام الحقيقية جاية من Graph API (socialSources.ts).
// مفيش كشط: نداءات oEmbed والبحث الرسمي بس، زي باقي المصادر.

const YOUTUBE = /https?:\/\/(?:www\.|m\.)?(?:youtube\.com\/(?:watch\?v=|shorts\/)|youtu\.be\/)([\w-]{11})[^\s)\]»"'<>]*/gi;
const TIKTOK = /https?:\/\/(?:www\.|m\.|vm\.|vt\.)?tiktok\.com\/[^\s)\]»"'<>]+/gi;
const INSTAGRAM = /https?:\/\/(?:www\.)?instagram\.com\/(?:reels?|p|tv)\/[^\s)\]»"'<>]+/gi;

/** بدايل يوتيوب في الرد الواحد: كل بحث ١٠٠ وحدة من حصة اليوم. */
const MAX_SEARCHES = 2;

type Env = (k: string) => string | undefined;
export interface VideoDeps {
  fetcher?: typeof fetch;
  env?: Env;
}

const trimEnd = (u: string) => u.replace(/[.,،؛!؟?]+$/u, "");

/** ٢٠٠ من oEmbed بتاع المنصة = الفيديو موجود وعام. أي حاجة تانية أو مهلة = مكسور. */
export async function videoAlive(url: string, fetcher: typeof fetch = fetch, timeoutMs = 5000): Promise<boolean> {
  const endpoint = /tiktok\.com/i.test(url)
    ? `https://www.tiktok.com/oembed?url=${encodeURIComponent(url)}`
    : `https://www.youtube.com/oembed?format=json&url=${encodeURIComponent(url)}`;
  try {
    const res = await fetcher(endpoint, { signal: AbortSignal.timeout(timeoutMs) });
    await res.body?.cancel();
    return res.status === 200;
  } catch {
    return false;
  }
}

/** أول فيديو يوتيوب شغال لـ[query] من البحث الرسمي، أو null. المفتاح عمره ما يطلع في الرد. */
export async function youtubeAlternative(query: string, deps: VideoDeps = {}): Promise<string | null> {
  const key = (deps.env ?? ((k) => Deno.env.get(k)))("YOUTUBE_API_KEY")?.trim();
  const q = query.trim();
  if (!key || q.length < 3) return null;
  const fetcher = deps.fetcher ?? fetch;
  const params = new URLSearchParams({
    part: "snippet", type: "video", videoEmbeddable: "true", maxResults: "5", q: q.slice(0, 120), key,
  });
  let ids: string[] = [];
  try {
    const res = await fetcher(`https://www.googleapis.com/youtube/v3/search?${params}`, { signal: AbortSignal.timeout(8000) });
    if (res.status !== 200) {
      await res.body?.cancel();
      return null;
    }
    const body = await res.json() as { items?: Array<{ id?: { videoId?: unknown } }> };
    ids = (body.items ?? []).map((i) => i.id?.videoId).filter((v): v is string => typeof v === "string" && /^[\w-]{11}$/.test(v));
  } catch {
    return null;
  }
  for (const id of ids) {
    const url = `https://www.youtube.com/watch?v=${id}`;
    if (await videoAlive(url, fetcher)) return url;
  }
  return null;
}

/** كلام السطر اللي فيه الرابط من غيره: اسم الأكلة أو الفيديو اللي الموديل كان يقصده. */
function lineAround(text: string, url: string): string {
  const line = text.split("\n").find((l) => l.includes(url)) ?? "";
  return line.split(url).join(" ").replace(/https?:\/\/\S+/g, " ").replace(/[*_#>`:|•\-–—▶️🎥📺]+/gu, " ")
    .replace(/\s+/g, " ").trim();
}

/** الرابط من النص ومعاه «:» اللي كانت قبله بالظبط — مش أي «:» تانية في الرد. */
export function dropLink(text: string, url: string): string {
  const escaped = url.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return text.replace(new RegExp(`:?[ \\t]*${escaped}`, "gu"), "").replace(/[ \t]{2,}/g, " ");
}

/** الرد بروابط فيديو شغالة بس: المكسور بيتبدّل بأول بديل شغال أو بيتشال. */
export async function videosForChat(reply: string, deps: VideoDeps = {}): Promise<string> {
  const fetcher = deps.fetcher ?? fetch;
  const found = (re: RegExp) => [...new Set((reply.match(re) ?? []).map(trimEnd))];
  const youtube = found(YOUTUBE);
  const tiktok = found(TIKTOK);
  const instagram = found(INSTAGRAM);
  if (youtube.length + tiktok.length + instagram.length === 0) return reply;

  const alive = new Map<string, boolean>(
    await Promise.all([...youtube, ...tiktok].map(async (u) => [u, await videoAlive(u, fetcher)] as const)),
  );
  let text = reply;
  let searches = 0;
  for (const url of youtube) {
    if (alive.get(url)) continue;
    const query = lineAround(text, url);
    const alternative = searches < MAX_SEARCHES && query.length >= 3
      ? (searches++, await youtubeAlternative(query, deps))
      : null;
    text = alternative ? text.split(url).join(alternative) : dropLink(text, url);
  }
  for (const url of tiktok) if (!alive.get(url)) text = dropLink(text, url);
  for (const url of instagram) text = dropLink(text, url);
  return text.trimEnd();
}
