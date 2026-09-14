// مفاتيح مرفوضة (401/403) بتتشال من الدوران مؤقتاً (٢٠٢٦-٠٩-١٤).
//
// فحص المفاتيح الحي بعد النشر لقى مفتاح Groq الأول بيرجع 401 على طول. في zad-brain الـ401
// بيترمي ConfigError ومابيتعادش — فكل مرة الدور ييجي على المفتاح ده (نص المرات) رجل Groq
// الاحتياطية كلها كانت بتفشل، حتى والمفتاح التاني شغال. هنا المفتاح المرفوض بيتعلّم «ميت»
// لمدة، والدوران بيعدّيه للي بعده. مفتاح 429 مش ميت — ده حد مؤقت وليه منطق تاني.

export const DEAD_KEY_MS = 30 * 60 * 1000;

export class DeadKeys {
  private until = new Map<string, number>();
  constructor(private now: () => number = Date.now) {}

  markIfRejected(key: string, status: number | undefined): boolean {
    if (status !== 401 && status !== 403) return false;
    this.until.set(key, this.now() + DEAD_KEY_MS);
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
