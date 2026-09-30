/**
 * What one live deals search is asked to look for.
 *
 * «العروض المتاحة لنواقصك» sent every low pantry row to one groq/compound-mini
 * call — five brands of water were five items, and a full pantry could send a
 * dozen. Compound runs a web search per item inside the call, so a long list
 * ran past the upstream timeout and the card said «تعذّر البحث» (owner,
 * 2026-09-30). The list is now de-duplicated and capped: the card shows six
 * deals at most, so asking for more only buys a timeout.
 */
export const MAX_DEAL_ITEMS = 5;

/** A compound search runs one web search per item; give it room past the default 25s. */
export const DEAL_SEARCH_TIMEOUT_MS = 50_000;

/** The distinct, non-empty item names to search, in the order given, at most [max]. */
export function dealSearchItems(raw: unknown, max = MAX_DEAL_ITEMS): string[] {
  const list = Array.isArray(raw) ? raw : typeof raw === "string" ? raw.split(/[،,]/) : [];
  const seen = new Set<string>();
  const out: string[] = [];
  for (const entry of list) {
    if (typeof entry !== "string") continue;
    const name = entry.trim().replace(/\s+/g, " ");
    if (!name) continue;
    const key = name.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(name);
    if (out.length >= max) break;
  }
  return out;
}

/**
 * Whether a price's currency, as the model read it off a page («جنيه», "EGP", «ج.م»),
 * is the account's [code]. The shopping list's estimates came back in whatever currency
 * the web answered — riyals for an Egyptian basket — and the total was wrong (owner,
 * 2026-10-01). An unknown code keeps everything, as before.
 */
const CURRENCY_WORDS: Record<string, RegExp> = {
  EGP: /EGP|E£|جنيه|ج\.?\s?م/i,
  SAR: /SAR|ريال سعودي|ر\.?\s?س|^ريال$/i,
  AED: /AED|درهم|د\.?\s?إ/i,
  KWD: /KWD|دينار كويتي|د\.?\s?ك/i,
  QAR: /QAR|ريال قطري|ر\.?\s?ق/i,
  BHD: /BHD|دينار بحريني|د\.?\s?ب/i,
  OMR: /OMR|ريال عماني|ر\.?\s?ع/i,
  JOD: /JOD|دينار أردني|د\.?\s?أ/i,
  TRY: /TRY|TL|₺|ليرة/i,
};

export function sameCurrency(code: string | null | undefined, text: string | null | undefined): boolean {
  const c = (code ?? "").trim().toUpperCase();
  const re = CURRENCY_WORDS[c];
  if (!re) return true;
  return re.test((text ?? "").trim());
}
