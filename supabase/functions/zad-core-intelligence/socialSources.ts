// socialSources.ts — يوتيوب وإنستجرام بواجهاتهم الرسمية بس (ZAD_PLAN ٤.١١، ٤.١٢).
//
// يوتيوب: YouTube Data API v3 بـ YOUTUBE_API_KEY — بحث = ١٠٠ وحدة من ١٠٬٠٠٠ في اليوم. إنستجرام: Graph API
// بـ INSTAGRAM_ACCESS_TOKEN على حساب Business (INSTAGRAM_BUSINESS_ACCOUNT_ID)، والبحث بالهاشتاج محتاج موافقة
// Meta على «Instagram Public Content Access» — التوكن لوحده مش كفاية، والفحص بيقول ده صريح.
// مفيش كشط ولا تنزيل فيديوهات: العنوان والرابط والقناة والتاريخ بس. المفتاح عمره ما يطلع في رد ولا لوج.

export interface YouTubeVideo {
  id: string;
  title: string;
  channel: string;
  published_at: string;
  url: string;
}

export interface SourceResult<T> {
  ok: boolean;
  status: number;
  /** سبب جوجل/ميتا لو النداء فشل (keyInvalid، quotaExceeded، OAuthException…) — من غير المفتاح. */
  reason?: string;
  items: T[];
}

const DAY_MS = 86_400_000;

// اللي بنقراه من ردود جوجل وميتا بس.
type ApiError = { error?: { errors?: Array<{ reason?: unknown }>; status?: unknown; type?: unknown; code?: unknown } };
type SearchItem = { id?: { videoId?: unknown }; snippet?: { title?: unknown; channelTitle?: unknown; publishedAt?: unknown } };

/** فيديوهات يوتيوب لبحث في بلد، الأحدث الأول، من آخر [days] يوم. */
export async function youtubeSearch(
  key: string,
  q: string,
  region: string,
  opts: { days?: number; max?: number; now?: number } = {},
): Promise<SourceResult<YouTubeVideo>> {
  const params = new URLSearchParams({
    part: "snippet", type: "video", q, regionCode: region.toUpperCase(), relevanceLanguage: "ar",
    order: "date", maxResults: String(Math.min(Math.max(opts.max ?? 8, 1), 25)),
    publishedAfter: new Date((opts.now ?? Date.now()) - (opts.days ?? 14) * DAY_MS).toISOString(),
    key,
  });
  try {
    const res = await fetch(`https://www.googleapis.com/youtube/v3/search?${params}`, { signal: AbortSignal.timeout(15000) });
    const body = await res.json().catch(() => null) as (ApiError & { items?: unknown }) | null;
    if (!res.ok) return { ok: false, status: res.status, reason: googleReason(body), items: [] };
    const items = (Array.isArray(body?.items) ? body.items : []) as SearchItem[];
    const videos: YouTubeVideo[] = [];
    for (const v of items) {
      const id = v?.id?.videoId;
      if (typeof id !== "string") continue;
      videos.push({
        id,
        title: String(v.snippet?.title ?? "").slice(0, 200),
        channel: String(v.snippet?.channelTitle ?? "").slice(0, 100),
        published_at: String(v.snippet?.publishedAt ?? ""),
        url: `https://www.youtube.com/watch?v=${id}`,
      });
    }
    return { ok: true, status: res.status, items: videos };
  } catch (e) {
    return { ok: false, status: 0, reason: String((e as Error)?.message ?? e).slice(0, 80), items: [] };
  }
}

function googleReason(body: ApiError | null): string | undefined {
  const r = body?.error?.errors?.[0]?.reason ?? body?.error?.status;
  return typeof r === "string" ? r.slice(0, 60) : undefined;
}

/** فحص الصحة: المفتاح موجود؟ وبحث واحد بيرجع إيه (١٠٠ وحدة — بيتنادى مع كل نشر بس). */
export async function youtubeProbe(key: string | undefined): Promise<Record<string, unknown>> {
  if (!key) return { configured: false };
  const r = await youtubeSearch(key, "عروض كارفور", "EG", { max: 1, days: 30 });
  return { configured: true, ok: r.ok, status: r.status, ...(r.reason ? { reason: r.reason } : {}), results: r.items.length };
}

const GRAPH = "https://graph.facebook.com/v21.0";

/**
 * فحص إنستجرام على خطوتين: الحساب نفسه بيرد بالتوكن ده؟ والبحث بالهاشتاج مسموح (Public Content Access)؟
 * «عروض» هاشتاج هنستخدمه أصلاً، فمابيضيّعش خانة من الـ٣٠ في الأسبوع.
 */
export async function instagramProbe(token: string | undefined, accountId: string | undefined): Promise<Record<string, unknown>> {
  if (!token || !accountId) return { configured: false, token: Boolean(token), account_id: Boolean(accountId) };
  const call = async (path: string): Promise<{ status: number; body: ApiError | null }> => {
    try {
      const res = await fetch(`${GRAPH}/${path}${path.includes("?") ? "&" : "?"}access_token=${encodeURIComponent(token)}`, {
        signal: AbortSignal.timeout(15000),
      });
      return { status: res.status, body: await res.json().catch(() => null) };
    } catch (e) {
      return { status: 0, body: { error: { type: String((e as Error)?.message ?? e).slice(0, 60) } } };
    }
  };
  const metaReason = (b: ApiError | null) => {
    const e = b?.error;
    return e ? `${String(e.type ?? "error").slice(0, 40)}${e.code ? `/${e.code}` : ""}` : undefined;
  };
  const account = await call(`${encodeURIComponent(accountId)}?fields=username`);
  if (account.status !== 200) return { configured: true, account: { ok: false, status: account.status, reason: metaReason(account.body) } };
  const tag = await call(`ig_hashtag_search?user_id=${encodeURIComponent(accountId)}&q=${encodeURIComponent("عروض")}`);
  return {
    configured: true,
    account: { ok: true, status: 200 },
    hashtag_search: { ok: tag.status === 200, status: tag.status, ...(tag.status === 200 ? {} : { reason: metaReason(tag.body) }) },
  };
}
