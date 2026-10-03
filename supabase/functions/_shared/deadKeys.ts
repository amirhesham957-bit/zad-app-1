// مفاتيح مرفوضة (401/403) بتتشال من الدوران مؤقتاً (٢٠٢٦-٠٩-١٤).
//
// فحص المفاتيح الحي بعد النشر لقى مفتاح Groq الأول بيرجع 401 على طول. في zad-brain الـ401
// بيترمي ConfigError ومابيتعادش — فكل مرة الدور ييجي على المفتاح ده (نص المرات) رجل Groq
// الاحتياطية كلها كانت بتفشل، حتى والمفتاح التاني شغال. هنا المفتاح المرفوض بيتعلّم «ميت»
// لمدة، والدوران بيعدّيه للي بعده. مفتاح 429 مش ميت — ده حد مؤقت وليه منطق تاني.
//
// ٢٠٢٦-١٠-٠٣: والـ429 كمان بيرتاح، بس على قد ما المزوّد قال (retry-after) مش ٣٠ دقيقة ثابتة:
// حد الدقيقة بيرجع بعد ثواني، وحد اليوم بيستاهل ساعة. من غير الراحة كل نداء كان بيبدأ بمفتاح
// خلصت حصته ويصرف عليه طلب قبل ما يعدّي.

export const DEAD_KEY_MS = 30 * 60 * 1000;
/** أطول راحة لمفتاح 429، حتى لو retry-after قال أكتر (حد اليوم). */
export const RATE_LIMIT_MAX_MS = 60 * 60 * 1000;
/** راحة مفتاح 429 من غير retry-after — حد الدقيقة هو الأشيع. */
export const RATE_LIMIT_DEFAULT_MS = 60 * 1000;

export class DeadKeys {
  private until = new Map<string, number>();
  constructor(private now: () => number = Date.now) {}

  markIfRejected(key: string, status: number | undefined): boolean {
    if (status !== 401 && status !== 403) return false;
    this.until.set(key, this.now() + DEAD_KEY_MS);
    return true;
  }

  /** 429 ⇒ المفتاح بيرتاح [retryAfterMs] (من ١ ث لحد ساعة)، أو دقيقة لو المزوّد ماقالش. */
  markIfRateLimited(key: string, status: number | undefined, retryAfterMs?: number): boolean {
    if (status !== 429) return false;
    const ms = retryAfterMs && retryAfterMs > 0
      ? Math.min(Math.max(retryAfterMs, 1000), RATE_LIMIT_MAX_MS)
      : RATE_LIMIT_DEFAULT_MS;
    this.until.set(key, Math.max(this.until.get(key) ?? 0, this.now() + ms));
    return true;
  }

  isDead(key: string): boolean {
    const t = this.until.get(key);
    if (t === undefined) return false;
    if (t <= this.now()) { this.until.delete(key); return false; }
    return true;
  }

  /** المفاتيح بترتيب الدوران من [start]، الحية الأول. لو كلهم ميتين بيرجعهم كلهم (آخر محاولة أحسن من مفيش). */
  order(keys: string[], start: number): string[] {
    const rotated = keys.map((_, i) => keys[(start + i) % keys.length]);
    const alive = rotated.filter((k) => !this.isDead(k));
    return alive.length ? alive : rotated;
  }
}
