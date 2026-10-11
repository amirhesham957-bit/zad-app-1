// searchQuality.ts — which sources a question may use, which results actually answer it,
// and today's gold price read off news headlines.
//
// Measured 2026-10-01: the brain's web_search stopped at the first source that returned
// anything, and Wikipedia's keyword search always returns something. «سعر الذهب اليوم في مصر
// عيار 21» came back as «حفل زفاف الأمير وليم وكيت ميدلتون», «سعر زجاجة المياه في السعودية» as
// «قائمة حلقات طاش ما طاش», and the answer was cached for six hours. Google News headlines for
// the same question carry the price itself («عيار 21 يسجل 6,120 جنيهًا»).

export interface SearchHit { title: string; url: string; snippet: string; published?: string }

const AR_DIGITS = "٠١٢٣٤٥٦٧٨٩";

/** Text as it is compared: Latin digits, no diacritics, one spelling per letter family. */
export function normalizeForMatch(s: string): string {
  return s
    .replace(/[٠-٩]/g, (d) => String(AR_DIGITS.indexOf(d)))
    .replace(/[ً-ٰٟـ]/g, "")
    .replace(/[أإآ]/g, "ا").replace(/ة/g, "ه").replace(/ى/g, "ي")
    // Egyptians write الدهب for الذهب.
    .replace(/ذ/g, "د")
    .toLowerCase();
}

const STOP = new Set([
  "في", "فى", "من", "علي", "عن", "الي", "مع", "يوم", "نهارده", "انهارده", "دلوقتي", "حين", "كام", "كم", "بكام", "بكم",
  "سعر", "اسعار", "تمن", "ثمن", "ايه", "اي", "هو", "هي", "ده", "دي", "دا", "مين", "امتي", "ازاي", "كيف", "ما", "ماذا",
  "هل", "لو", "او", "قد", "اخر", "مره", "عايز", "عاوز", "ابغي", "ابي", "قولي", "قلي", "عرفني", "النهارده",
  "the", "a", "an", "of", "in", "on", "what", "is", "are", "price", "today", "how", "much", "who", "when", "for",
]);

/** The words a result must share with the question. */
export function keyTerms(query: string): string[] {
  const words = normalizeForMatch(query).split(/[^\p{L}\p{N}]+/u)
    .map((w) => w.replace(/^(وال|بال|فال|كال|لل|ال)(?=[\p{L}\p{N}]{2,})/u, ""))
    .filter((w) => w.length >= 2 && !STOP.has(w));
  return [...new Set(words)];
}

const PRICE_Q = /سعر|اسعار|بكام|بكم|كام|تمن|ثمن|price|cost/;
const LIVE_Q = new RegExp(
  "سعر|اسعار|بكام|بكم|تمن|ثمن|دولار|يورو|ريال|دهب|عيار|بورصه|سهم|اخبار|خبر|نهارده|انهارده|اليوم|دلوقتي|الحين|امبارح|امس|" +
    "ماتش|مباراه|نتيجه|طقس|الجو|حراره|price|today|news|score|weather|rate",
);

/** Prices, news, scores, weather: what is true today, which an encyclopedia cannot answer. */
export function isLiveQuery(query: string): boolean {
  return LIVE_Q.test(normalizeForMatch(query));
}

export function isPriceQuery(query: string): boolean {
  return PRICE_Q.test(normalizeForMatch(query));
}

/** Share of the question's key words found in the result. */
export function relevance(query: string, hit: Pick<SearchHit, "title" | "snippet">): number {
  const terms = keyTerms(query);
  if (terms.length === 0) return 1;
  const text = normalizeForMatch(`${hit.title} ${hit.snippet}`);
  return terms.filter((t) => text.includes(t)).length / terms.length;
}

/** A result that answers the question: at least half its key words, and a number for a price. */
export function answersQuery(query: string, hit: Pick<SearchHit, "title" | "snippet">): boolean {
  const terms = keyTerms(query);
  const needed = Math.ceil(terms.length / 2);
  const text = normalizeForMatch(`${hit.title} ${hit.snippet}`);
  const matched = terms.filter((t) => text.includes(t)).length;
  if (matched < needed) return false;
  if (isPriceQuery(query) && !/\d/.test(text)) return false;
  return true;
}

export function keepAnswering(query: string, hits: SearchHit[]): SearchHit[] {
  return hits.filter((h) => answersQuery(query, h));
}

/** How long an accepted answer may be served again: a price moves within the hour. */
export function cacheTtlMs(query: string): number {
  return isLiveQuery(query) ? 20 * 60 * 1000 : 6 * 60 * 60 * 1000;
}

// ── Google News locale per market ────────────────────────────────────────────────────────

const MARKET: Record<string, { name: string; currencyAr: string; currency: string }> = {
  EG: { name: "مصر", currencyAr: "جنيه", currency: "EGP" },
  SA: { name: "السعودية", currencyAr: "ريال", currency: "SAR" },
  AE: { name: "الإمارات", currencyAr: "درهم", currency: "AED" },
  KW: { name: "الكويت", currencyAr: "دينار", currency: "KWD" },
  QA: { name: "قطر", currencyAr: "ريال", currency: "QAR" },
  BH: { name: "البحرين", currencyAr: "دينار", currency: "BHD" },
  OM: { name: "عمان", currencyAr: "ريال", currency: "OMR" },
  JO: { name: "الأردن", currencyAr: "دينار", currency: "JOD" },
};

export function marketOf(country: unknown) {
  const cc = typeof country === "string" && MARKET[country.toUpperCase()] ? country.toUpperCase() : "EG";
  return { code: cc, ...MARKET[cc] };
}

/** Google News RSS for a market. Arabic questions read the market's own Arabic press. */
export function googleNewsUrl(query: string, country: unknown, arabic: boolean): string {
  const cc = marketOf(country).code;
  const locale = arabic ? `hl=ar&gl=${cc}&ceid=${cc}:ar` : "hl=en-US&gl=US&ceid=US:en";
  return `https://news.google.com/rss/search?q=${encodeURIComponent(query)}&${locale}`;
}

/**
 * Bing News RSS for a market. Measured 2026-10-01: from the Supabase function Google News
 * answered 503 (blocked) while Bing News returned the day's gold headlines, and its item
 * descriptions carry the figures («عيار 21 مبلغ 6145 جنيهًا، وسجل عيار 24 مبلغ 7022»).
 */
export function bingNewsUrl(query: string, country: unknown, arabic: boolean): string {
  const cc = marketOf(country).code;
  const locale = arabic ? `setlang=ar&cc=${cc}` : "setlang=en&cc=US";
  return `https://www.bing.com/news/search?q=${encodeURIComponent(query)}&format=rss&${locale}`;
}

/**
 * Google answers an EU address with its cookie-consent page instead of the feed; Supabase's
 * functions run in Europe, which is the likeliest reason the news feed came back empty there
 * while it returned 92 items from elsewhere the same day. These cookies say consent was given.
 */
export const GOOGLE_CONSENT_COOKIE = "CONSENT=YES+cb.20240101-00-p0.en+FX+000; SOCS=CAESEwgDEgk0ODE3Nzk3MjQaAmVuIAEaBgiA_LyaBg";

// ── Gold, read off headlines ─────────────────────────────────────────────────────────────

export interface GoldQuote { karat: string; price: number; currency: string; source: string; published?: string; samples: number }

/** «عيار 21 يسجل 6,120 جنيهًا» ⇒ 21: 6120. A move («يرتفع 10 جنيهات») is too small to be a price. */
export function goldPricesInTitle(title: string): Array<{ karat: string; price: number }> {
  const text = title.replace(/[٠-٩]/g, (d) => String(AR_DIGITS.indexOf(d))).replace(/٬/g, ",");
  const out: Array<{ karat: string; price: number }> = [];
  for (const m of text.matchAll(/عيار\s*(24|22|21|18)\D{0,30}?(\d{1,3}(?:,\d{3})+|\d{3,6})(?:\.\d+)?/g)) {
    const price = Number(m[2].replace(/,/g, ""));
    if (price >= 100) out.push({ karat: m[1], price });
  }
  return out;
}

/** The median of the freshest headlines per karat, with the newest one as the source. */
export function goldQuotes(hits: SearchHit[], currency: string, now = Date.now()): GoldQuote[] {
  const fresh = hits.filter((h) => {
    const t = h.published ? Date.parse(h.published) : NaN;
    return Number.isNaN(t) || now - t < 36 * 3600 * 1000;
  });
  const byKarat = new Map<string, Array<{ price: number; hit: SearchHit }>>();
  for (const hit of fresh) {
    // Bing's descriptions carry the figures more often than the headlines do.
    const seen = new Set<string>();
    for (const q of [...goldPricesInTitle(hit.title), ...goldPricesInTitle(hit.snippet)]) {
      if (seen.has(q.karat)) continue;
      seen.add(q.karat);
      byKarat.set(q.karat, [...(byKarat.get(q.karat) ?? []), { price: q.price, hit }]);
    }
  }
  const quotes: GoldQuote[] = [];
  for (const karat of ["24", "22", "21", "18"]) {
    const rows = byKarat.get(karat);
    if (!rows?.length) continue;
    const sorted = [...rows].sort((a, b) => a.price - b.price);
    const median = sorted[Math.floor(sorted.length / 2)].price;
    const newest = [...rows].sort((a, b) => Date.parse(b.hit.published ?? "") - Date.parse(a.hit.published ?? ""))[0].hit;
    const source = newest.title.includes(" - ") ? newest.title.slice(newest.title.lastIndexOf(" - ") + 3) : newest.url;
    quotes.push({ karat, price: median, currency, source, published: newest.published, samples: rows.length });
  }
  return quotes;
}

// ── «آخر مرة» — the newest edition first (2026-10-11) ───────────────────────────────────
//
// «مين كسب كاس العالم للأندية آخر مرة؟» counted as a settled fact, so the chain went to
// Wikipedia, and the results came back in the encyclopedia's order: the 2025 edition, the
// 2019 one, the 2026 *World Cup* (another competition) — with nothing saying which is
// newest. The acceptance probe failed it 2 runs in 6 (Manchester City 2023, «المصدر:
// ويكيبيديا»). A question that asks for the latest keeps only the results whose *title*
// names the thing best, and orders them newest year first.

const LATEST_Q = /(^|[^\p{L}])(اخر|احدث|الاخير|الاخيره|الحالي|الحاليه|حاليا|السنه دي|last|latest|newest|most recent|current|reigning)([^\p{L}]|$)/u;

/** Words that ask about time or a result, not about the thing itself. */
const LATEST_WORDS = new Set([
  "اخر", "احدث", "اخير", "اخيره", "حالي", "حاليه", "حاليا", "كسب", "فاز", "بطل", "مره", "نسخه", "سنه",
  "last", "latest", "newest", "recent", "most", "current", "reigning", "won", "win", "wins", "winner", "winners",
  "champion", "champions", "edition",
]);

export function asksLatest(query: string | null | undefined): boolean {
  return LATEST_Q.test(normalizeForMatch(String(query ?? "")));
}

function yearOf(title: string): number | null {
  const years = [...normalizeForMatch(title).matchAll(/(?<!\d)(19|20)\d{2}(?!\d)/g)].map((m) => Number(m[0]));
  return years.length ? Math.max(...years) : null;
}

/**
 * For a «latest» question: the results whose title names the thing best (best title match
 * over [queries], ties kept) — the series' own page first (a title with no year: «the current
 * champions are…»), then the editions newest year first. An edition dated after [nowYear] has
 * not been played and is dropped.
 */
export function latestFirst(
  queries: Array<string | null | undefined>,
  hits: SearchHit[],
  nowYear: number = new Date().getUTCFullYear(),
): SearchHit[] {
  const termSets = queries.filter((q): q is string => !!q && q.trim() !== "")
    .map((q) => keyTerms(q).filter((t) => !LATEST_WORDS.has(t)))
    .filter((t) => t.length > 0);
  if (termSets.length === 0 || hits.length === 0) return hits;
  const score = (h: SearchHit) => {
    const title = normalizeForMatch(h.title);
    return Math.max(...termSets.map((ts) => ts.filter((t) => title.includes(t)).length / ts.length));
  };
  const best = Math.max(...hits.map(score));
  if (best === 0) return hits;
  // A year still ahead is an edition not played yet («كأس العالم للأندية 2029»: «من المقرر أن تقام…») — it
  // went first on 2026-10-11 and the answer fell back to memory. Not a result; left out.
  const named = hits.filter((h) => score(h) === best && (yearOf(h.title) ?? 0) <= nowYear);
  const dated = named.filter((h) => yearOf(h.title) !== null).sort((a, b) => yearOf(b.title)! - yearOf(a.title)!);
  const undated = named.filter((h) => yearOf(h.title) === null);
  // The series' own page first: it states the current holder whatever editions the search returned
  // (one phrasing brought back only the 2019 edition — «newest» among what came back is not the latest).
  return [...undated, ...dated];
}

/**
 * The English page of an Arabic Wikipedia page (its interlanguage link), as a hit. Arabic intros
 * of a series or an edition rarely name the winner; the English ones do («the current world
 * champions are Chelsea»). Used for a «latest» question when the model wrote no English query.
 * null when there is no English page or the read failed.
 */
export async function englishTwin(arTitle: string, get: (url: string) => Promise<unknown> = defaultGet): Promise<SearchHit | null> {
  try {
    const links = await get(
      `https://ar.wikipedia.org/w/api.php?action=query&titles=${encodeURIComponent(arTitle)}&prop=langlinks&lllang=en&format=json&utf8=1`,
    ) as { query?: { pages?: Record<string, { langlinks?: Array<{ "*"?: string }> }> } };
    const en = Object.values(links?.query?.pages ?? {})[0]?.langlinks?.[0]?.["*"];
    if (!en) return null;
    const page = await get(
      `https://en.wikipedia.org/w/api.php?action=query&titles=${encodeURIComponent(en)}&prop=extracts&exintro=1&explaintext=1&exchars=700&format=json&utf8=1`,
    ) as { query?: { pages?: Record<string, { title?: string; extract?: string }> } };
    const p = Object.values(page?.query?.pages ?? {})[0];
    const snippet = (p?.extract ?? "").replace(/\s+/g, " ").trim();
    if (!p?.title || !snippet) return null;
    return { title: p.title, url: `https://en.wikipedia.org/wiki/${encodeURIComponent(p.title.replace(/ /g, "_"))}`, snippet };
  } catch {
    return null;
  }
}

async function defaultGet(url: string): Promise<unknown> {
  const res = await fetch(url, {
    headers: { "User-Agent": "ZadAssistant/1.0 (household app; contact via app store listing)" },
    signal: AbortSignal.timeout(6000),
  });
  if (!res.ok) throw new Error(`wikipedia ${res.status}`);
  return await res.json();
}

/**
 * The question's topic for an encyclopedia search: the words left once question and time words go
 * («مين كسب كاس العالم للأندية آخر مرة؟» ⇒ «كاس العالم للأندية»). Arabic Wikipedia answered the whole
 * colloquial question with unrelated pages; the topic alone finds the series. The question itself
 * when nothing is left.
 */
export function topicOf(query: string): string {
  const words = query.replace(/[؟?!.,،]/g, " ").split(/\s+/).filter((w) => {
    const k = normalizeForMatch(w).replace(/^(وال|بال|فال|كال|لل|ال)(?=[\p{L}\p{N}]{2,})/u, "");
    return k !== "" && !STOP.has(k) && !LATEST_WORDS.has(k);
  });
  return words.length ? words.join(" ") : query.trim();
}

/** A «latest» answer from Wikipedia: [ranked] with [twin] right after the first hit. */
export function withTwin(ranked: SearchHit[], twin: SearchHit | null): SearchHit[] {
  if (!twin || ranked.some((h) => h.url === twin.url)) return ranked;
  return [...ranked.slice(0, 1), twin, ...ranked.slice(1)];
}
