// رابط العرض (طلب المالك ١٠/١١): عرض الصبح كان بيتبعت باسم المنتج والمحل من غير رابط لما مصدره بحث حي
// (نون، كارفور، النهدي…). القواعد بالترتيب:
// ١. رابط أفلييت (أمازون بالتاج) بيتبعت بس لو ردّ 200 ساعتها.
// ٢. من غيره: رابط بحث جوه موقع المحل باسم المنتج كامل — بس للمحلات اللي قالبها ردّ 200 (المقاس ١٠/١١:
//    نون والدواء ولولو 403، بنده 404، فمش هنا) — وبرضه بيتفحص ساعتها.
// ٣. مفيش رابط مضمون ⇒ الرسالة زي ما هي، نص بس.

/** تاجات أمازون: سر المشروع لو موجود، وإلا اللي التطبيق بيستعمله من ٩/١١. */
export function amazonTag(country: string, env: (k: string) => string | undefined = (k) => Deno.env.get(k)): string | null {
  if (country === "EG") return env("ZAD_AMAZON_EG_TAG")?.trim() || "zad04-21";
  if (country === "SA") return env("ZAD_AMAZON_SA_TAG")?.trim() || "zad0b-21";
  return null;
}

const AMAZON_HOST: Record<string, string> = { EG: "www.amazon.eg", SA: "www.amazon.sa" };
const AMAZON_STORE = /amazon|أمازون|امازون/i;

/** رقم المنتج في أمازون من رابطه، أو null. */
export function asinOf(url: unknown): string | null {
  if (typeof url !== "string" || !/^https:\/\/(www\.)?amazon\.(eg|sa)\//.test(url.trim())) return null;
  return /\/(?:dp|gp\/product)\/([A-Z0-9]{10})(?:[/?]|$)/.exec(url.trim())?.[1] ?? null;
}

/** قوالب البحث اللي ردّت 200 في المقاس (١٠/١١). */
const STORE_SEARCH: Array<{ store: RegExp; country: string; url: (q: string) => string }> = [
  { store: /كارفور|carrefour/i, country: "EG", url: (q) => `https://www.carrefouregypt.com/mafegy/ar/search?keyword=${q}` },
  { store: /كارفور|carrefour/i, country: "SA", url: (q) => `https://www.carrefourksa.com/mafsau/ar/search?keyword=${q}` },
  { store: /النهدي|نهدي|nahdi/i, country: "SA", url: (q) => `https://www.nahdionline.com/ar-sa/search?query=${q}` },
  { store: /سبينيس|سبينس|spinneys/i, country: "EG", url: (q) => `https://www.spinneys-egypt.com/ar/search?q=${q}` },
  { store: /الدانوب|دانوب|danube/i, country: "SA", url: (q) => `https://www.danube.sa/ar/search?q=${q}` },
  { store: /سعودي|seoudi/i, country: "EG", url: (q) => `https://seoudisupermarket.com/ar/catalogsearch/result/?q=${q}` },
];

export interface DealLink {
  kind: "amazon" | "store_search";
  url: string;
}

/** الرابط المرشّح قبل الفحص، أو null. [item] = اسم المنتج كامل. */
export function candidateLink(
  deal: { item: string; store: string; product_url?: string | null },
  country: string,
  env?: (k: string) => string | undefined,
): DealLink | null {
  const item = deal.item.trim();
  if (item.length < 2) return null;
  const q = encodeURIComponent(item);
  if (AMAZON_STORE.test(deal.store) || asinOf(deal.product_url)) {
    const tag = amazonTag(country, env);
    const host = AMAZON_HOST[country];
    if (!tag || !host) return null;
    const asin = asinOf(deal.product_url);
    const t = encodeURIComponent(tag);
    return { kind: "amazon", url: asin ? `https://${host}/dp/${asin}?tag=${t}` : `https://${host}/s?k=${q}&tag=${t}` };
  }
  const search = STORE_SEARCH.find((s) => s.country === country && s.store.test(deal.store));
  return search ? { kind: "store_search", url: search.url(q) } : null;
}

/** 200 بعد التحويلات وإلا مفيش. فشل أو مهلة = مش مضمون. */
export async function answers200(url: string, fetcher: typeof fetch = fetch, timeoutMs = 5000): Promise<boolean> {
  try {
    const res = await fetcher(url, {
      method: "GET",
      redirect: "follow",
      signal: AbortSignal.timeout(timeoutMs),
      headers: { "user-agent": "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/124 Mobile Safari/537.36" },
    });
    await res.body?.cancel();
    return res.status === 200;
  } catch {
    return false;
  }
}

/**
 * العرض برابط: مصدره المتخزّن لو https، وإلا رابط أمازون أو بحث المحل لو ردّ 200، وإلا زي ما هو.
 * الرابط بيمشي في `source` — نفس الحقل اللي زرار تيليجرام ولمسة الإشعار بيقروه (٤.٢٠، ٤.٢٢).
 */
export async function withDealLink<T extends { item: string; store: string; product_url?: string | null; source?: { kind: string; url: string | null; until: string | null } | null }>(
  deal: T | null,
  country: string,
  deps: { fetcher?: typeof fetch; env?: (k: string) => string | undefined } = {},
): Promise<T | null> {
  if (!deal) return deal;
  if (typeof deal.source?.url === "string" && /^https:\/\/\S{4,500}$/.test(deal.source.url)) return deal;
  const link = candidateLink(deal, country, deps.env);
  if (!link || !(await answers200(link.url, deps.fetcher))) return deal;
  return { ...deal, source: { kind: link.kind, url: link.url, until: deal.source?.until ?? null } };
}

// ── روابط أمازون في رد الشات (بلاغ المالك ١٠/١١) ────────────────────────────────────────────────
// الموديل كتب «[أمازون ناو](https://www.amazon.eg/gp/browse.html?node=…)»: من غير تاج، فمفيش عمولة، وتيليجرام
// والتطبيق مابيقروش Markdown فطلع خام ومقلوب. هنا: الرابط بيتكتب نضيف «النص: الرابط» عشان الموبايل يفتحه
// (تطبيق أمازون بيلقطه)، ورابط أمازون مصر/السعودية بياخد التاج، وبيتبعت بس لو ردّ 200 — وإلا النص لوحده.

const MD_LINK = /\[([^\]\n]{1,80})\]\((https?:\/\/[^\s)]+)\)/g;
// المسار اختياري: «https://www.amazon.eg» لوحده اتبعت من غير تاج (بلاغ المالك ١٠/١١، بعد #٤٥٧).
const AMAZON_URL = /https?:\/\/(?:www\.)?amazon\.(eg|sa)(?:\/[^\s)\]»"'<>]*)?/gi;

/** رابط أمازون بالتاج بتاعنا (بدل أي تاج تاني)، أو null لو مش أمازون مصر/السعودية. */
export function withAmazonTag(raw: string, env?: (k: string) => string | undefined): string | null {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return null;
  }
  const country = /(^|\.)amazon\.eg$/.test(url.hostname) ? "EG" : /(^|\.)amazon\.sa$/.test(url.hostname) ? "SA" : null;
  const tag = country ? amazonTag(country, env) : null;
  if (!tag || url.protocol !== "https:" && url.protocol !== "http:") return null;
  url.protocol = "https:";
  url.searchParams.set("tag", tag);
  return url.toString();
}

/** الرد زي ما هيتبعت: روابط Markdown نضيفة، وروابط أمازون بالتاج ومفحوصة. */
export async function linksForChat(
  reply: string,
  deps: { fetcher?: typeof fetch; env?: (k: string) => string | undefined } = {},
): Promise<string> {
  let text = reply.replace(MD_LINK, (_m, label: string, url: string) => `${label.trim()}: ${url}`);
  const found = [...new Set((text.match(AMAZON_URL) ?? []).map((u) => u.replace(/[.,،؛!؟?]+$/u, "")))];
  for (const original of found) {
    const tagged = withAmazonTag(original, deps.env);
    const ok = tagged !== null && await answers200(tagged, deps.fetcher);
    text = ok
      ? text.split(original).join(tagged!)
      : text.split(original).join("").replace(/:\s*(?=\s|$)/gu, "").replace(/[ \t]{2,}/g, " ");
  }
  return text.trimEnd();
}
