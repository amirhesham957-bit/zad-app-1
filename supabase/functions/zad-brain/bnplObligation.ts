import type { ObligationRow } from "./obligationCandidate.ts";
import { hashKey } from "./hashKey.ts";

// شركات "اشتري دلوقتي وادفع بعدين" في كل سوق — نفس قايمة التطبيق
// (zad_flutter/lib/shared/subscriptions/domain/bnpl.dart). مصر كانت فاليو بس، والعميل
// المصري بيدفع سيمبل وسهولة وكونتكت وأمان وحالاً كمان (٢٠٢٦-٠٩-٣٠).
export const BNPL_PROVIDERS = new Set([
  "تابي", "تمارة", "تمارا", "فاليو", "سيمبل", "سهولة", "كونتكت", "أمان", "حالا", "مدفوع", "تالي",
  "tabby", "tamara", "valu", "sympl", "souhoola", "contact", "aman", "halan", "madfu", "mispay",
  "postpay", "cashew", "taly",
]);

/**
 * بند 32.1 — نسخة أسرع من detectObligationCandidate مخصوصة لتابي/تمارة/فاليو: مرتين
 * بس مش ٣ شهور متفرقة. خطة تقسيط عادةً ٣-٤ دفعات شهرية — لو استنينا نفس عتبة الالتزام
 * العادي (٣ شهور)، هنكتشفها وهي خلصت أو قربت تخلص، مش وهي لسه بادئة.
 *
 * false positive مش مستبعد نظريًا (عميل اشترى مرتين بنفس المزوّد وصدفة نفس المبلغ من
 * غير خطة فعلية) لكنه نادر عمليًا: bank_name هنا هوية مُصنَّفة من التطبيق المُرسِل
 * (SaBankParser)، مش تخمين نصي على اسم تاجر غامض، والمطابقة على المبلغ **بالظبط** مش
 * بتقريب — تقاطع الاتنين ضيق. زي detectObligationCandidate تمامًا: بيستبعد أي حاجة
 * متسجلة كالتزام بالفعل، ومرشح واحد بس في المرة.
 */
export function detectBnplObligationCandidate(
  expenseTx: Array<{ bank_name: string | null; amount: number; created_at: string }>,
  existingObligations: ObligationRow[],
): { title: string; amount: number; provider: string; due_day: number; dedupe_key: string } | null {
  const known = new Set(existingObligations.filter((o) => o.provider).map((o) => `${o.provider}_${o.amount}`));
  const groups = new Map<string, { provider: string; amount: number; dates: Date[] }>();
  for (const t of expenseTx) {
    const provider = (t.bank_name ?? "").trim().toLowerCase();
    if (!BNPL_PROVIDERS.has(provider)) continue;
    const key = `${provider}_${t.amount}`;
    if (known.has(key)) continue;
    if (!groups.has(key)) groups.set(key, { provider: t.bank_name!.trim(), amount: t.amount, dates: [] });
    groups.get(key)!.dates.push(new Date(t.created_at));
  }
  let best: { provider: string; amount: number; dates: Date[] } | null = null;
  for (const g of groups.values()) {
    if (g.dates.length < 2) continue;
    if (!best || g.dates.length > best.dates.length) best = g;
  }
  if (!best) return null;
  const mostRecent = best.dates.reduce((a, b) => (b > a ? b : a));
  return {
    title: `قسط ${best.provider}`,
    amount: best.amount,
    provider: best.provider,
    due_day: mostRecent.getDate(),
    dedupe_key: `obligation_confirm_bnpl_${hashKey(`${best.provider}_${best.amount}`)}`,
  };
}
