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

// ── مفاتيح متعددة (طلب المالك ٢٢/١١): كل مفتاح ١٬٠٠٠ بحث مجاني في الشهر، فبندوّر بينهم ──────────────────────
// المفاتيح: TAVILY_API_KEY (ممكن فيه كذا مفتاح بفاصلة) و TAVILY_API_KEY_1..TAVILY_API_KEY_20. من غير تكرار.
// مفتاح ردّ بـ٤٣٢/٤٣٣ (الباقة خلصت) بيرتاح لحد أول الشهر الجاي تقريباً، و٤٢٩ ساعة، و٤٠١/٤٠٣ (مفتاح غلط) يوم.
// الراحة في ذاكرة النسخة بس: لو النسخة اتعمّرت من جديد بنجرّب تاني (غلطة واحدة زيادة، مش بحث ضايع).

export const TAVILY_MAX_KEYS = 20;

export function tavilyKeys(env: (k: string) => string | undefined = (k) => Deno.env.get(k)): string[] {
  const raw = [env("TAVILY_API_KEY") ?? "", ...Array.from({ length: TAVILY_MAX_KEYS }, (_, i) => env(`TAVILY_API_KEY_${i + 1}`) ?? "")];
  const keys = raw.flatMap((v) => v.split(",")).map((k) => k.trim()).filter((k) => k !== "");
  return [...new Set(keys)];
}

const resting = new Map<string, number>();
let cursor = 0;

/** كام وقت (ms) المفتاح يرتاح بعد الحالة دي، أو 0 لو الحالة مش بتوقّف المفتاح. */
export function restFor(status: number): number {
  if (status === 432 || status === 433) return 15 * 86_400_000;
  if (status === 429) return 3_600_000;
  if (status === 401 || status === 403) return 86_400_000;
  return 0;
}

export function resetTavilyRotation() {
  resting.clear();
  cursor = 0;
}

export interface TavilyRotated extends TavilyResult {
  /** كام مفتاح اتجرّب، وكام مفتاح في الدايرة. */
  tried: number;
  total: number;
}

/** بحث بالتدوير: بيبدأ من المفتاح اللي دوره، ولو وقف بيعدّي للي بعده. */
export async function tavilySearchRotating(
  keys: readonly string[], query: string, maxResults: number, now = Date.now(),
  search: typeof tavilySearch = tavilySearch,
): Promise<TavilyRotated> {
  const total = keys.length;
  let last: TavilyResult = { ok: false, status: 0, reason: "no key", items: [] };
  let tried = 0;
  const start = total ? cursor % total : 0;
  for (let i = 0; i < total; i++) {
    const key = keys[(start + i) % total];
    if ((resting.get(key) ?? 0) > now) continue;
    tried++;
    last = await search(key, query, maxResults);
    if (last.ok) {
      cursor = (start + i + 1) % total; // الدور الجاي على اللي بعده، فالحمل بيتوزّع
      return { ...last, tried, total };
    }
    const rest = restFor(last.status);
    if (rest === 0) break; // مهلة أو خطأ سيرفر: مفتاح تاني مش هيفرق
    resting.set(key, now + rest);
  }
  return { ...last, tried, total };
}

function tavilyReason(body: { detail?: unknown } | null, key: string): string | undefined {
  const d = body?.detail;
  const r = typeof d === "string" ? d : (d as { error?: unknown } | undefined)?.error;
  return typeof r === "string" ? r.split(key).join("…").slice(0, 80) : undefined;
}

/** فحص الصحة: كام مفتاح موجود، وكل واحد بيرد إيه (أرقام بس — المفتاح نفسه مايطلعش). بيتنادى مع كل نشر بس. */
export async function tavilyProbe(keys: readonly string[] | string | undefined): Promise<Record<string, unknown>> {
  const list = typeof keys === "string" ? [keys] : [...(keys ?? [])];
  if (list.length === 0) return { configured: false, keys: 0 };
  const rows = await Promise.all(list.map((k) => tavilySearch(k, "عروض كارفور مصر", 1)));
  const working = rows.filter((r) => r.ok).length;
  const failed = rows.filter((r) => !r.ok).map((r) => ({ status: r.status, ...(r.reason ? { reason: r.reason } : {}) }));
  const first = rows[0];
  return { configured: true, keys: list.length, working, ...(failed.length ? { failed } : {}), ok: working > 0, status: first.status, ...(first.reason ? { reason: first.reason } : {}), results: first.items.length };
}
