// channelVideos.ts — فيديوهات آخر أسبوعين من قنوات شيفات ومحلات معروفة لكل بلد (ZAD_OR_PLAN م٦.٧).
//
// يوتيوب Data API الرسمي بـ YOUTUBE_API_KEY بس، من غير كشط: channels.list بالـ@handle (وحدة واحدة) ⇐ قايمة الرفع
// ⇐ playlistItems.list (وحدة واحدة). ده أرخص ١٠٠ مرة من search.list اللي بيستعمله باقي الكود. قايمة الرفع بتتحفظ
// في الذاكرة، ونتيجة البلد بتتحفظ ٦ ساعات، فالتطبيق مايحرقش الكوتة. الـhandle اللي مابيتحلّش بيتخطى بهدوء.
// المفتاح عمره ما يطلع في رد ولا لوج.

export type ChannelKind = "chef" | "store";
export interface ChannelEntry { handle: string; kind: ChannelKind }
export interface ChannelVideo {
  id: string;
  title: string;
  channel: string;
  handle: string;
  kind: ChannelKind;
  published_at: string;
  url: string;
  thumbnail: string | null;
}
export interface ChannelVideosResult { ok: boolean; reason?: string; videos: ChannelVideo[] }

/** القايمة بإيد المالك: الـhandle بدون @. اتأكدنا إنها موجودة على يوتيوب ١١/٢٠٢٦؛ اللي مابيتحلّش بيتخطى. */
export const CHANNELS: Record<string, ChannelEntry[]> = {
  EG: [
    { handle: "AblaFahita", kind: "chef" },
    { handle: "ChefShadi", kind: "chef" },
    { handle: "kazyonmarket", kind: "store" },
  ],
  SA: [
    { handle: "SaudiChef", kind: "chef" },
    { handle: "OthaimMarkets", kind: "store" },
    { handle: "Tamimi_Markets", kind: "store" },
    { handle: "CarrefourSaudi", kind: "store" },
    { handle: "Panda_Saudi", kind: "store" },
  ],
  AE: [
    { handle: "carrefouruae", kind: "store" },
    { handle: "LuLuHypermarkets", kind: "store" },
  ],
};

export const HANDLE_RE = /^[A-Za-z0-9._-]{3,30}$/;
const DAY_MS = 86_400_000;
const RESULT_TTL_MS = 6 * 3_600_000;
const API = "https://www.googleapis.com/youtube/v3";

type Fetcher = (url: string, init?: RequestInit) => Promise<Response>;

const uploadsCache = new Map<string, string>();
const resultCache = new Map<string, { at: number; videos: ChannelVideo[] }>();

export function channelsFor(country: unknown): ChannelEntry[] {
  const cc = typeof country === "string" ? country.toUpperCase() : "";
  return (CHANNELS[cc] ?? []).filter((c) => HANDLE_RE.test(c.handle));
}

/** الأحدث الأول، من غير تكرار، من غير فيديو محذوف أو خاص، وفي آخر [days] يوم بس. */
export function pickVideos(videos: ChannelVideo[], max: number, days: number, now: number): ChannelVideo[] {
  const seen = new Set<string>();
  const out: ChannelVideo[] = [];
  const fresh = videos
    .filter((v) => v.id && v.title && v.title !== "Private video" && v.title !== "Deleted video")
    .filter((v) => {
      const t = Date.parse(v.published_at);
      return Number.isFinite(t) && now - t <= days * DAY_MS && t <= now + DAY_MS;
    })
    .sort((a, b) => Date.parse(b.published_at) - Date.parse(a.published_at));
  for (const v of fresh) {
    if (seen.has(v.id)) continue;
    seen.add(v.id);
    out.push(v);
    if (out.length >= max) break;
  }
  return out;
}

async function uploadsPlaylist(key: string, handle: string, fetcher: Fetcher): Promise<string | null> {
  const hit = uploadsCache.get(handle);
  if (hit) return hit;
  const params = new URLSearchParams({ part: "contentDetails", forHandle: `@${handle}`, key });
  const res = await fetcher(`${API}/channels?${params}`, { signal: AbortSignal.timeout(10000) });
  if (!res.ok) throw new Error(`youtube_${res.status}`);
  const body = await res.json().catch(() => null) as { items?: Array<{ contentDetails?: { relatedPlaylists?: { uploads?: unknown } } }> } | null;
  const id = body?.items?.[0]?.contentDetails?.relatedPlaylists?.uploads;
  if (typeof id !== "string" || !/^[\w-]{10,40}$/.test(id)) return null;
  uploadsCache.set(handle, id);
  return id;
}

type PlaylistItem = { snippet?: { title?: unknown; channelTitle?: unknown; publishedAt?: unknown; resourceId?: { videoId?: unknown }; thumbnails?: { medium?: { url?: unknown }; default?: { url?: unknown } } } };

async function recentUploads(key: string, entry: ChannelEntry, fetcher: Fetcher): Promise<ChannelVideo[]> {
  const playlist = await uploadsPlaylist(key, entry.handle, fetcher);
  if (!playlist) return [];
  const params = new URLSearchParams({ part: "snippet", playlistId: playlist, maxResults: "8", key });
  const res = await fetcher(`${API}/playlistItems?${params}`, { signal: AbortSignal.timeout(10000) });
  if (!res.ok) throw new Error(`youtube_${res.status}`);
  const body = await res.json().catch(() => null) as { items?: PlaylistItem[] } | null;
  const out: ChannelVideo[] = [];
  for (const it of Array.isArray(body?.items) ? body!.items! : []) {
    const id = it?.snippet?.resourceId?.videoId;
    if (typeof id !== "string" || !/^[\w-]{6,20}$/.test(id)) continue;
    const thumb = it.snippet?.thumbnails?.medium?.url ?? it.snippet?.thumbnails?.default?.url;
    out.push({
      id,
      title: String(it.snippet?.title ?? "").slice(0, 200),
      channel: String(it.snippet?.channelTitle ?? "").slice(0, 100),
      handle: entry.handle,
      kind: entry.kind,
      published_at: String(it.snippet?.publishedAt ?? ""),
      url: `https://www.youtube.com/watch?v=${id}`,
      thumbnail: typeof thumb === "string" && thumb.startsWith("https://") ? thumb : null,
    });
  }
  return out;
}

/** آخر فيديوهات قنوات بلد. ok:false بس لو مفيش مفتاح أو كل القنوات فشلت؛ قناة واحدة بتفشل بتتخطى. */
export async function channelVideos(
  key: string | undefined,
  country: unknown,
  opts: { kind?: ChannelKind; max?: number; days?: number; fetcher?: Fetcher; now?: number } = {},
): Promise<ChannelVideosResult> {
  if (!key) return { ok: false, reason: "no_key", videos: [] };
  const entries = channelsFor(country).filter((c) => !opts.kind || c.kind === opts.kind);
  if (entries.length === 0) return { ok: true, videos: [] };
  const now = opts.now ?? Date.now();
  const max = Math.min(Math.max(opts.max ?? 6, 1), 12);
  const days = opts.days ?? 14;
  const cacheKey = `${String(country).toUpperCase()}:${opts.kind ?? "all"}`;
  const cached = resultCache.get(cacheKey);
  if (cached && now - cached.at < RESULT_TTL_MS) return { ok: true, videos: pickVideos(cached.videos, max, days, now) };
  const fetcher = opts.fetcher ?? fetch;
  const settled = await Promise.allSettled(entries.map((e) => recentUploads(key, e, fetcher)));
  const all = settled.flatMap((s) => s.status === "fulfilled" ? s.value : []);
  if (settled.every((s) => s.status === "rejected")) {
    const msg = String((settled[0] as PromiseRejectedResult).reason?.message ?? "youtube_error").replace(key, "").slice(0, 60);
    return { ok: false, reason: msg, videos: [] };
  }
  resultCache.set(cacheKey, { at: now, videos: all });
  return { ok: true, videos: pickVideos(all, max, days, now) };
}

export function _resetChannelCachesForTest(): void {
  uploadsCache.clear();
  resultCache.clear();
}
