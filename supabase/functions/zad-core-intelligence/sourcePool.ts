// sourcePool.ts — لما مصدر بحث يرفض، بيستريح ساعتين (طلب المالك ٨/١١).
//
// webSearchSnippets أصلاً بيمشي على قايمة مصادر بالترتيب. الجديد: 429 أو 403 معناهم المصدر قال «كفاية»، فبنسيبه ساعتين بدل ما نخبط عليه مع كل بحث.
// ده احترام للحد مش التفاف عليه: كل المصادر هنا مسموح بيها (مفتاح رسمي أو RSS عام). مفيش كشط لتيك توك أو إنستجرام، ومفيش بروكسي ولا تغيير هوية.

export const SOURCE_REST_MS = 2 * 3_600_000;
/** نتيجة بحث العروض بتتحفظ المدة دي: نفس السؤال مايتسألش مرتين. */
export const DEAL_SEARCH_CACHE_MS = 6 * 3_600_000;

/** محاولات المصدر ده فيها رفض صريح؟ («tavily:429»، «google_cse:403»). */
export function refused(attempts: readonly string[]): boolean {
  return attempts.some((a) => /:(?:429|403)(?:\s|$)/.test(a));
}

/** من غير اللي مستريحين. لو كلهم مستريحين القايمة بترجع كاملة: البحث مايقفش أبداً. */
export function withoutResting<T extends readonly [string, unknown]>(ordered: readonly T[], resting: ReadonlySet<string>): T[] {
  const awake = ordered.filter(([name]) => !resting.has(name));
  return awake.length > 0 ? awake : [...ordered];
}

export function dealSearchCacheKey(query: string, maxResults: number, country: unknown): string {
  return `deal_search:${String(country ?? "")}:${maxResults}:${query.replace(/\s+/g, " ").trim().slice(0, 200)}`;
}
