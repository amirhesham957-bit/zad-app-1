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
