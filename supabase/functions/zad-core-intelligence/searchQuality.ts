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
    for (const q of goldPricesInTitle(hit.title)) {
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
