import { hashKey } from "./hashKey.ts";

export interface ObligationRow {
  id: string; title: string; amount: number; kind: string;
  due_day: number | null; due_date: string | null; recurrence: string;
  confirmed: boolean; active: boolean; provider?: string | null;
}

// nextDueDate() moved to Postgres as zad_obligation_next_due() — same rules ('once' that
// already passed is assumed paid; a recurring obligation with no due_day is refused
// rather than guessed; quarterly/yearly step 3/12 months off due_day because the table
// has no due_month), but now shared with the `committed` total instead of being a second
// copy that could select a different set of obligations than the sum it sat next to.

/**
 * تجميع مصاريف بنفس (تاجر، مبلغ) على ٣ شهور مختلفة على الأقل خلال آخر ٤ شهور = مرشح
 * التزام ثابت (إيجار/قسط). بيرجع أقوى مرشح واحد بس (نفس قيد "سؤال واحد في المرة" اللي
 * validateAskUser بيفرضه أصلاً)، ومستبعد أي حاجة مسجلة كـ zad_obligations أو
 * zad_subscriptions فعلاً — مش هيكرر التزام موجود ولا يبلّغ عن اشتراك.
 */
export function detectObligationCandidate(
  expenseTx: Array<{ title: string; merchant_name: string | null; amount: number; created_at: string }>,
  existingObligations: ObligationRow[],
  activeSubscriptions: Array<{ title: string; amount: number }>,
  now: Date,
): { title: string; amount: number; due_day: number; dedupe_key: string } | null {
  const fourMonthsAgo = new Date(now.getTime() - 120 * 86400000);
  const known = new Set([
    ...existingObligations.map((o) => `${o.title}_${o.amount}`),
    ...activeSubscriptions.map((s) => `${s.title}_${s.amount}`),
  ]);
  const groups = new Map<string, { title: string; amount: number; dates: Date[] }>();
  for (const t of expenseTx) {
    const merchant = (t.merchant_name ?? t.title ?? "").trim();
    if (!merchant) continue;
    const d = new Date(t.created_at);
    if (d < fourMonthsAgo) continue;
    const key = `${merchant}_${t.amount}`;
    if (known.has(key)) continue;
    if (!groups.has(key)) groups.set(key, { title: merchant, amount: t.amount, dates: [] });
    groups.get(key)!.dates.push(d);
  }
  let best: { title: string; amount: number; dates: Date[] } | null = null;
  for (const g of groups.values()) {
    const distinctMonths = new Set(g.dates.map((d) => `${d.getFullYear()}_${d.getMonth()}`));
    if (distinctMonths.size < 3) continue;
    if (!best || g.dates.length > best.dates.length) best = g;
  }
  if (!best) return null;
  const mostRecent = best.dates.reduce((a, b) => (b > a ? b : a));
  return {
    title: best.title,
    amount: best.amount,
    due_day: mostRecent.getDate(),
    dedupe_key: `obligation_confirm_${hashKey(`${best.title}_${best.amount}`)}`,
  };
}
