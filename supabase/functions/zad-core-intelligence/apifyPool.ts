/**
 * Apify — متصفح حقيقي على سيرفرات Apify للنشرات الرسمية اللي صفحتها محتاجة جافاسكريبت (طلب المالك ١٤/١١).
 *
 * الحدود (قرار المالك ١٤/١١، «Apify القانوني بس»، ونفس قاعدة ZAD_PLAN «العروض من مصادر قانونية بس»):
 *   - بنفتح صفحة موقع محل في OFFICIAL_FLYER_SITES بس، بعد ما robots.txt بتاعه يسمح — نفس الصفحة اللي أي زائر بيشوفها.
 *   - من غير بروكسي (`useApifyProxy: false`) ومن غير أي التفاف: موقع بيحجب = بنسيبه.
 *   - **مفيش** كشط تيك توك ولا إنستجرام ولا فيسبوك ولا خرايط جوجل ولا تطبيقات التوصيل — كلهم ضد شروطهم.
 *
 * المفاتيح في Supabase Secrets، مش في جدول: `APIFY_API_TOKEN` (مفتاح واحد أو كذا مفتاح بفاصلة/مسافة/سطر) و/أو
 * `APIFY_API_TOKEN_1..9`. كل نداء بيبدأ من مفتاح عشوائي (مفيش ذاكرة بين النداءات في Edge) وبيعدّي للي بعده لو المفتاح
 * اترفض أو رصيده خلص (401/402/403/429) — نفس فكرة مسبح جيميناي.
 */

/** الأكتور الرسمي بتاع Apify: كروم حقيقي، والـpageFunction بيرجّع الـHTML بعد ما الصفحة تتحمّل. */
export const APIFY_WEB_SCRAPER = "apify~web-scraper";

/** وقت الرن على Apify (ثانية). الفانكشن نفسها ليها حد ~١٥٠ ثانية. */
export const APIFY_RUN_TIMEOUT_S = 90;

/** أكبر HTML بنقبله من الصفحة. */
export const MAX_RENDERED_HTML = 3_000_000;

/** كل المفاتيح من غير تكرار، بالترتيب: الجماعي الأول ثم المرقّمة. */
export function apifyTokens(env: (name: string) => string | undefined): string[] {
  const raw = [env("APIFY_API_TOKEN") ?? ""];
  for (let i = 1; i <= 9; i++) raw.push(env(`APIFY_API_TOKEN_${i}`) ?? "");
  const out: string[] = [];
  for (const chunk of raw) {
    for (const t of chunk.split(/[\s,;]+/)) {
      const token = t.trim();
      if (token.length >= 10 && !out.includes(token)) out.push(token);
    }
  }
  return out;
}

/** المفتاح ده خلص أو اترفض ⇒ جرّب اللي بعده. أي حاجة تانية (500، timeout) = المشكلة مش في المفتاح. */
export function apifyKeyExhausted(status: number): boolean {
  return status === 401 || status === 402 || status === 403 || status === 429;
}

/** مدخل web-scraper لصفحة واحدة: من غير بروكسي، وبيحترم robots.txt هو كمان. */
export function renderInput(url: string): Record<string, unknown> {
  return {
    startUrls: [{ url }],
    maxPagesPerCrawl: 1,
    maxCrawlingDepth: 0,
    respectRobotsTxtFile: true,
    proxyConfiguration: { useApifyProxy: false },
    injectJQuery: false,
    pageFunction: "async function pageFunction(context) { await context.waitFor(3000); " +
      "return { url: context.request.url, html: document.documentElement.outerHTML }; }",
  };
}

export type RenderResult =
  | { ok: true; html: string; key_index: number; tried: number }
  | { ok: false; reason: string; tried: number };

/**
 * يفتح [url] في متصفح Apify ويرجّع الـHTML. [start] = أول مفتاح يتجرّب (عشوائي في الإنتاج، ثابت في التستات).
 * بيلف على المفاتيح كلها مرة واحدة بالكتير.
 */
export async function renderPageWithApify(
  url: string,
  tokens: string[],
  opts: { fetchFn?: typeof fetch; start?: number; timeoutMs?: number } = {},
): Promise<RenderResult> {
  if (tokens.length === 0) return { ok: false, reason: "no_apify_keys", tried: 0 };
  const fetchFn = opts.fetchFn ?? fetch;
  const start = opts.start ?? Math.floor(Math.random() * tokens.length);
  const endpoint = `https://api.apify.com/v2/acts/${APIFY_WEB_SCRAPER}/run-sync-get-dataset-items?timeout=${APIFY_RUN_TIMEOUT_S}&clean=true`;
  let lastReason = "all_keys_exhausted";
  for (let i = 0; i < tokens.length; i++) {
    const index = (start + i) % tokens.length;
    let res: Response;
    try {
      res = await fetchFn(endpoint, {
        method: "POST",
        headers: { "Authorization": `Bearer ${tokens[index]}`, "Content-Type": "application/json" },
        body: JSON.stringify(renderInput(url)),
        signal: AbortSignal.timeout(opts.timeoutMs ?? (APIFY_RUN_TIMEOUT_S + 15) * 1000),
      });
    } catch (e) {
      // الشبكة أو الوقت: مفتاح تاني مش هيفرق، ومفيش داعي نحرق رصيده.
      return { ok: false, reason: (e as Error).name === "TimeoutError" ? "timeout" : "fetch_failed", tried: i + 1 };
    }
    if (apifyKeyExhausted(res.status)) {
      await res.body?.cancel();
      console.warn(`[apify] key #${index + 1} answered ${res.status} — next key`);
      lastReason = `key_${res.status}`;
      continue;
    }
    if (!res.ok) {
      await res.body?.cancel();
      return { ok: false, reason: `apify_${res.status}`, tried: i + 1 };
    }
    const items = await res.json().catch(() => null);
    const html = Array.isArray(items) && typeof items[0]?.html === "string" ? items[0].html as string : "";
    if (!html) return { ok: false, reason: "empty_page", tried: i + 1 };
    return { ok: true, html: html.slice(0, MAX_RENDERED_HTML), key_index: index, tried: i + 1 };
  }
  return { ok: false, reason: lastReason, tried: tokens.length };
}

/** للفحص بعد النشر: كام رابط PDF وكام صورة في الصفحة، وعينة منهم — عشان شكل رابط النشرة يتكتب في OFFICIAL_FLYER_SITES. */
export function flyerLinkSample(html: string, base: string, limit = 15): { pdfs: string[]; images: string[] } {
  const abs = (u: string) => {
    try {
      return new URL(u.replace(/&amp;/g, "&"), base).toString();
    } catch {
      return "";
    }
  };
  const pdfs = new Set<string>();
  const images = new Set<string>();
  for (const m of html.matchAll(/(?:href|src|data-[a-z-]+)\s*=\s*["']([^"']+)["']/gi)) {
    const u = abs(m[1]);
    if (!u.startsWith("http")) continue;
    if (/\.pdf(\?|#|$)/i.test(u)) pdfs.add(u);
    else if (/(flyer|leaflet|brochure|offer|promo|catalog|magazine|عروض|نشر)/i.test(u) && /\.(jpe?g|png|webp)(\?|#|$)/i.test(u)) images.add(u);
  }
  return { pdfs: [...pdfs].slice(0, limit), images: [...images].slice(0, limit) };
}
