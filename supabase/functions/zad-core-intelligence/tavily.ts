// tavily.ts — بحث Tavily (TAVILY_API_KEY، ١٬٠٠٠ بحث مجاني في الشهر من غير كارت) وفحصه (ZAD_PLAN ٤.١٤).
//
// المصدر بقى في سلسلة البحث من ٢٥/١٠ (بعد مفتاح البحث، وأوله لما الـgrounding بيستريح)، بس مفيش حاجة كانت
// بتقول المفتاح موجود ولا بيرد: لو اتشال أو الباقة خلصت، السلسلة بتعدّيه بهدوء. الفحص في provider_health
// بيقول ده بعد كل نشر. المفتاح عمره ما يطلع في رد ولا لوج.

export interface TavilyHit { title: string; url: string; snippet: string }

export interface TavilyResult {
  ok: boolean;
  status: number;
  /** سبب Tavily لو النداء فشل (مفتاح غلط، الباقة خلصت…) — من غير المفتاح. */
  reason?: string;
  items: TavilyHit[];
}

export async function tavilySearch(key: string, query: string, maxResults: number): Promise<TavilyResult> {
  try {
    const res = await fetch("https://api.tavily.com/search", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
      body: JSON.stringify({ query, max_results: maxResults, include_answer: false, search_depth: "basic" }),
      signal: AbortSignal.timeout(12000),
    });
    const body = await res.json().catch(() => null) as { results?: unknown; detail?: { error?: unknown } | unknown } | null;
    if (!res.ok) return { ok: false, status: res.status, reason: tavilyReason(body, key), items: [] };
    // Tavily's `answer` is its own model's summary, with no page or date behind it: on 24/10 it said
    // «مانشستر سيتي 2023» for the last Club World Cup and the brain repeated it first. The pages go
    // up as they are; the summary does not.
    const items = ((Array.isArray(body?.results) ? body.results : []) as Array<{ title?: string; url?: string; content?: string }>)
      .filter((r) => r.url).map((r) => ({ title: r.title ?? r.url!, url: r.url!, snippet: String(r.content ?? "").slice(0, 500) }));
    return { ok: true, status: res.status, items: items.slice(0, maxResults) };
  } catch (e) {
    return { ok: false, status: 0, reason: String((e as Error)?.message ?? e).slice(0, 50), items: [] };
  }
}

function tavilyReason(body: { detail?: unknown } | null, key: string): string | undefined {
  const d = body?.detail;
  const r = typeof d === "string" ? d : (d as { error?: unknown } | undefined)?.error;
  return typeof r === "string" ? r.split(key).join("…").slice(0, 80) : undefined;
}

/** فحص الصحة: المفتاح موجود؟ وبحث واحد بيرجع إيه (بحث من الألف — بيتنادى مع كل نشر بس). */
export async function tavilyProbe(key: string | undefined): Promise<Record<string, unknown>> {
  if (!key) return { configured: false };
  const r = await tavilySearch(key, "عروض كارفور مصر", 1);
  return { configured: true, ok: r.ok, status: r.status, ...(r.reason ? { reason: r.reason } : {}), results: r.items.length };
}
