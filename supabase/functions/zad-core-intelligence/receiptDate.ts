/**
 * تاريخ الفاتورة المطبوع — عشان مصروف فاتورة من الشهر اللي فات مايتحسبش على الشهر ده.
 *
 * التطبيق كان بيسجل أي فاتورة ممسوحة بتاريخ لحظة المسح، فورقة من ٣ أسابيع كانت
 * بتدخل ميزانية الشهر الحالي. الموديل دلوقتي بيرجّع التاريخ المطبوع لو موجود، والدالة
 * دي بتقبله بس لو هو تاريخ حقيقي بصيغة YYYY-MM-DD ومش في المستقبل ومش أقدم من سنة —
 * أي حاجة غير كده (غالباً قراية غلط) بترجع null والتطبيق بيستخدم تاريخ النهارده زي الأول.
 */
export function receiptPurchaseDate(raw: unknown, now: Date = new Date()): string | null {
  if (typeof raw !== "string") return null;
  const m = raw.trim().match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!m) return null;
  const [y, mo, d] = [Number(m[1]), Number(m[2]), Number(m[3])];
  const at = new Date(Date.UTC(y, mo - 1, d));
  // 2026-02-30 rolls over to March — not a real date.
  if (at.getUTCFullYear() !== y || at.getUTCMonth() !== mo - 1 || at.getUTCDate() !== d) return null;
  const day = 24 * 60 * 60 * 1000;
  // A day of slack for time zones: the account's "today" may be UTC's tomorrow.
  if (at.getTime() > now.getTime() + day) return null;
  if (at.getTime() < now.getTime() - 366 * day) return null;
  return m[0];
}
