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

export interface InstagramPost {
  id: string;
  caption: string;
  permalink: string;
  timestamp: string;
  /** صورة البوست (أو أول صورة في الألبوم) — للقراية بس، مابتتخزنش. null للفيديو. */
  image_url: string | null;
}

type MediaItem = {
  id?: unknown; caption?: unknown; permalink?: unknown; timestamp?: unknown; media_type?: unknown; media_url?: unknown;
};

/** الهاشتاج اللي بندوّر بيه على عروض محل: «عروض_كارفور». الهاشتاج مابيقبلش مسافات ولا رموز. */
export function storeHashtag(store: string): string {
  const name = store.replace(/[^\p{L}\p{N}\s]/gu, " ").trim().replace(/\s+/g, "_");
  return `عروض_${name}`.slice(0, 60);
}

/**
 * بوستات هاشتاج من آخر [days] يوم، الأحدث الأول (ZAD_PLAN ٤.١٢). Graph API الرسمي: ig_hashtag_search بيرجّع رقم الهاشتاج،
 * وtop_media البوستات العامة عليه. كل هاشتاج جديد بيعدّ من ٣٠ في الأسبوع على الحساب — فالمحلات في الأسبوع محسوبة.
 */
export async function instagramHashtagPosts(
  token: string,
  accountId: string,
  tag: string,
  opts: { days?: number; max?: number; now?: number } = {},
): Promise<SourceResult<InstagramPost>> {
  const get = async (path: string): Promise<{ status: number; body: (ApiError & { data?: unknown }) | null }> => {
    try {
      const res = await fetch(`${GRAPH}/${path}&access_token=${encodeURIComponent(token)}`, { signal: AbortSignal.timeout(15000) });
      return { status: res.status, body: await res.json().catch(() => null) };
    } catch (e) {
      return { status: 0, body: { error: { type: String((e as Error)?.message ?? e).slice(0, 60) } } };
    }
  };
  const reason = (b: ApiError | null) => {
    const e = b?.error;
    return e ? `${String(e.type ?? "error").slice(0, 40)}${e.code ? `/${e.code}` : ""}` : undefined;
  };
  const user = encodeURIComponent(accountId);
  const found = await get(`ig_hashtag_search?user_id=${user}&q=${encodeURIComponent(tag)}`);
  if (found.status !== 200) return { ok: false, status: found.status, reason: reason(found.body), items: [] };
  const first = (Array.isArray(found.body?.data) ? found.body!.data : [])[0] as { id?: unknown } | undefined;
  if (typeof first?.id !== "string") return { ok: true, status: 200, items: [] };
  const fields = "id,caption,permalink,timestamp,media_type,media_url";
  const media = await get(`${encodeURIComponent(first.id)}/top_media?user_id=${user}&fields=${fields}&limit=25`);
  if (media.status !== 200) return { ok: false, status: media.status, reason: reason(media.body), items: [] };
  const since = (opts.now ?? Date.now()) - (opts.days ?? 10) * DAY_MS;
  const posts: InstagramPost[] = [];
  for (const m of (Array.isArray(media.body?.data) ? media.body!.data : []) as MediaItem[]) {
    if (typeof m?.id !== "string" || typeof m.permalink !== "string") continue;
    if (!/^https:\/\/www\.instagram\.com\/(p|reel)\/[\w-]+\/?$/.test(m.permalink)) continue;
    const at = Date.parse(String(m.timestamp ?? ""));
    if (!Number.isFinite(at) || at < since) continue;
    const image = m.media_type === "IMAGE" || m.media_type === "CAROUSEL_ALBUM";
    posts.push({
      id: m.id,
      caption: String(m.caption ?? "").slice(0, 1500),
      permalink: m.permalink,
      timestamp: String(m.timestamp),
      image_url: image && typeof m.media_url === "string" && m.media_url.startsWith("https://") ? m.media_url : null,
    });
  }
  posts.sort((a, b) => Date.parse(b.timestamp) - Date.parse(a.timestamp));
  return { ok: true, status: 200, items: posts.slice(0, Math.min(Math.max(opts.max ?? 6, 1), 25)) };
}

// ── التوكن بيتجدد لوحده (٤.١٢، قرار ٤/١١: مفيش خطوة يدوية) ──────────────────────────────────────────────────────
// توكن فيسبوك طويل العمر بيخلص بعد ٦٠ يوم؛ توكن الصفحة المتاخد منه مالوش انتهاء. debug_token بيقول أنهي، والتبديل
// (fb_exchange_token) محتاج مفاتيح التطبيق. التوكن الجديد بيتخزن في الـVault (zad_instagram_token_save).

/** قبل الانتهاء بالمدة دي التوكن بيتبدّل. */
export const TOKEN_REFRESH_DAYS = 20;

export interface TokenInfo {
  ok: boolean;
  status: number;
  /** ثواني يونكس؛ ٠ = مالوش انتهاء. */
  expires_at?: number;
  reason?: string;
}

/** تاريخ انتهاء التوكن من Meta. من غير مفاتيح التطبيق التوكن بيفحص نفسه (صاحب التطبيق). */
export async function instagramTokenInfo(token: string, appId?: string, appSecret?: string): Promise<TokenInfo> {
  const checker = appId && appSecret ? `${appId}|${appSecret}` : token;
  try {
    const res = await fetch(
      `${GRAPH}/debug_token?input_token=${encodeURIComponent(token)}&access_token=${encodeURIComponent(checker)}`,
      { signal: AbortSignal.timeout(15000) },
    );
    const body = await res.json().catch(() => null) as (ApiError & { data?: { is_valid?: unknown; expires_at?: unknown } }) | null;
    if (res.status !== 200 || !body?.data) {
      const e = body?.error;
      return { ok: false, status: res.status, reason: e ? `${String(e.type ?? "error").slice(0, 40)}${e.code ? `/${e.code}` : ""}` : "no_data" };
    }
    if (body.data.is_valid === false) return { ok: false, status: 200, reason: "invalid" };
    const exp = Number(body.data.expires_at);
    return { ok: true, status: 200, expires_at: Number.isFinite(exp) && exp >= 0 ? exp : undefined };
  } catch (e) {
    return { ok: false, status: 0, reason: String((e as Error)?.message ?? e).slice(0, 60) };
  }
}

/** التوكن محتاج يتبدّل؟ مالوش انتهاء (٠) أو تاريخ مش معروف = لأ؛ فاضل أقل من [TOKEN_REFRESH_DAYS] = آه. */
export function tokenNeedsRefresh(info: TokenInfo, nowMs = Date.now()): boolean {
  if (!info.ok || !info.expires_at) return false;
  return info.expires_at * 1000 - nowMs < TOKEN_REFRESH_DAYS * DAY_MS;
}

/** الأيام الفاضلة (مقرّبة لتحت)، أو null لو مالوش انتهاء أو مش معروف. */
export function tokenDaysLeft(info: TokenInfo, nowMs = Date.now()): number | null {
  if (!info.ok || !info.expires_at) return null;
  return Math.floor((info.expires_at * 1000 - nowMs) / DAY_MS);
}

/** توكن طويل جديد مكان [token] (fb_exchange_token). */
export async function exchangeLongLivedToken(
  token: string,
  appId: string,
  appSecret: string,
  nowMs = Date.now(),
): Promise<{ ok: boolean; token?: string; expires_at?: string | null; reason?: string }> {
  try {
    const url = `${GRAPH}/oauth/access_token?grant_type=fb_exchange_token&client_id=${encodeURIComponent(appId)}` +
      `&client_secret=${encodeURIComponent(appSecret)}&fb_exchange_token=${encodeURIComponent(token)}`;
    const res = await fetch(url, { signal: AbortSignal.timeout(15000) });
    const body = await res.json().catch(() => null) as (ApiError & { access_token?: unknown; expires_in?: unknown }) | null;
    if (res.status !== 200 || typeof body?.access_token !== "string" || body.access_token.length < 20) {
      const e = body?.error;
      return { ok: false, reason: e ? `${String(e.type ?? "error").slice(0, 40)}${e.code ? `/${e.code}` : ""}` : `status_${res.status}` };
    }
    const secs = Number(body.expires_in);
    return { ok: true, token: body.access_token, expires_at: secs > 0 ? new Date(nowMs + secs * 1000).toISOString() : null };
  } catch (e) {
    return { ok: false, reason: String((e as Error)?.message ?? e).slice(0, 60) };
  }
}

/**
 * مفاتيح تطبيق Meta بأي اسم معقول اتحط بيه في سوبابيز (META_APP_ID، FACEBOOK_APP_ID، INSTAGRAM_APP_ID، INSTA_ID…)،
 * وMETA_ الأول. بيرجع الأسامي اللي لقاها عشان الفحص يقولها — الأسامي بس، عمر القيمة ما تطلع.
 */
const APP_PREFIX = "(META|FACEBOOK|FB|INSTAGRAM|INSTA|IG)";
export function metaAppKeys(env: Record<string, string>): { id?: string; secret?: string; idName?: string; secretName?: string } {
  const rank = (n: string) => ["META", "FACEBOOK", "FB", "INSTAGRAM", "INSTA", "IG"].findIndex((p) => n.toUpperCase().startsWith(p));
  const pick = (re: RegExp) => Object.keys(env).filter((n) => re.test(n) && env[n]?.trim()).sort((a, b) => rank(a) - rank(b))[0];
  const idName = pick(new RegExp(`^${APP_PREFIX}_?(APP_?)?(CLIENT_?)?ID$`, "i"));
  const secretName = pick(new RegExp(`^${APP_PREFIX}_?(APP_?)?(CLIENT_?)?SECRET$`, "i"));
  return { id: idName ? env[idName].trim() : undefined, secret: secretName ? env[secretName].trim() : undefined, idName, secretName };
}
