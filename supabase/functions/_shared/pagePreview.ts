// pagePreview.ts — صورة المعاينة بتاعة صفحة العرض (og:image)، زي ما واتساب بيعمل معاينة للينك (طلب المالك ٦/١١).
//
// عروض `search` (٣٤ من ٨٥ يوم ٦/١١) كانت بتتعرض بمربع أخضر فاضي: صورتها الوحيدة كانت صورة يوتيوب، وكتالوج
// أمازون صوره كلها Unsplash (صور جاهزة، التطبيق بيرفضها صح). الصفحة نفسها بتعلن صورتها في <meta og:image>.
//
// ممنوع هنا: صفحات أمازون — شروط Amazon Associates بتسمح بصور المنتج من PA-API أو SiteStripe بس، والسحب من
// الصفحة ممكن يقفل التاج (zad0b-21 / zad04-21). وإنستجرام بيرجّع صفحة دخول، وروابط صوره بتنتهي بعد ساعات.

const SKIP_HOSTS = /(^|\.)(amazon\.[a-z.]+|media-amazon\.com|ssl-images-amazon\.com|images-amazon\.com|amzn\.[a-z]+|instagram\.com|cdninstagram\.com|facebook\.com|fbcdn\.net)$/i;
const MAX_BYTES = 300_000;

/** رابط https عادي لاسم دومين (مش IP ولا localhost)، ومش من المصادر الممنوعة. */
export function previewableUrl(raw: string | null | undefined): URL | null {
  if (typeof raw !== "string" || raw.length > 500) return null;
  let u: URL;
  try {
    u = new URL(raw.trim());
  } catch {
    return null;
  }
  if (u.protocol !== "https:" || u.username || u.password) return null;
  const host = u.hostname.toLowerCase();
  if (!host.includes(".") || /^[\d.]+$/.test(host) || host.includes(":") || host === "localhost") return null;
  if (host.endsWith(".local") || host.endsWith(".internal") || SKIP_HOSTS.test(host)) return null;
  return u;
}

const decode = (s: string) =>
  s.replace(/&amp;/g, "&").replace(/&quot;/g, '"').replace(/&#0?39;/g, "'").replace(/&#x2F;/gi, "/").trim();

/** الصورة اللي الصفحة بتعلنها: og:image، أو og:image:secure_url، أو twitter:image — بالترتيب ده. */
export function previewImageFrom(html: string, page: URL): string | null {
  const metas = html.match(/<meta\b[^>]*>/gi) ?? [];
  const found = new Map<string, string>();
  for (const tag of metas) {
    const key = /\b(?:property|name)\s*=\s*["']([^"']+)["']/i.exec(tag)?.[1]?.toLowerCase();
    const content = /\bcontent\s*=\s*["']([^"']*)["']/i.exec(tag)?.[1];
    if (key && content && !found.has(key)) found.set(key, decode(content));
  }
  for (const key of ["og:image:secure_url", "og:image", "og:image:url", "twitter:image", "twitter:image:src"]) {
    const v = found.get(key);
    if (!v) continue;
    let img: URL;
    try {
      img = new URL(v, page);
    } catch {
      continue;
    }
    if (img.protocol === "http:") img.protocol = "https:";
    const s = img.toString();
    if (img.protocol === "https:" && s.length <= 500 && !SKIP_HOSTS.test(img.hostname)) return s;
  }
  return null;
}

/** بيجيب أول ٣٠٠ ألف بايت من الصفحة ويطلّع صورتها. أي فشل = null (المربع زي ما هو). */
export async function fetchPreviewImage(raw: string, timeoutMs = 4_000): Promise<string | null> {
  const page = previewableUrl(raw);
  if (!page) return null;
  try {
    const res = await fetch(page, {
      headers: { "user-agent": "ZadLinkPreview/1.0 (+link preview)", accept: "text/html" },
      redirect: "follow",
      signal: AbortSignal.timeout(timeoutMs),
    });
    if (!res.ok || !res.body || !/html/i.test(res.headers.get("content-type") ?? "")) {
      await res.body?.cancel();
      return null;
    }
    const finalUrl = previewableUrl(res.url) ?? page;
    const reader = res.body.getReader();
    const chunks: Uint8Array[] = [];
    let size = 0;
    while (size < MAX_BYTES) {
      const { done, value } = await reader.read();
      if (done || !value) break;
      chunks.push(value);
      size += value.length;
      // الـmeta في الـ<head>: أول ما يخلص مافيش داعي نكمّل.
      if (new TextDecoder().decode(value).includes("</head>")) break;
    }
    await reader.cancel().catch(() => {});
    const html = new TextDecoder().decode(concat(chunks, size));
    return previewImageFrom(html, finalUrl);
  } catch {
    return null;
  }
}

function concat(chunks: Uint8Array[], size: number): Uint8Array {
  const out = new Uint8Array(size);
  let at = 0;
  for (const c of chunks) {
    out.set(c, at);
    at += c.length;
  }
  return out;
}
