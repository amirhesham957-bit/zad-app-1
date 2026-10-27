// spendByPerson.ts — الصرف لكل شخص في البيت (ZAD_PLAN ٥.٣).
//
// «صرفنا كام على يوسف الشهر ده؟» من zad_transactions.for_person (20261027060000). الحساب من المعاملات اللي اللقطة
// بتقراها خلاص (١٢٠ يوم)، فمفيش نداء زيادة. المصروف بس، ومن غير التحويلات؛ الشخص متوحّد بـnormalizeForPerson
// وقت الكتابة، فـ«ماما» و«أمي» نفس السطر. المعاملات اللي مالهاش شخص مابتظهرش هنا — دي العميل أو البيت كله.

export const SPEND_BY_PERSON_DAYS = 30;

export interface PersonTxn {
  amount: number | string | null;
  category: string | null;
  txn_kind: string | null;
  is_expense: boolean | null;
  created_at: string;
  for_person?: string | null;
}

export interface PersonSpend {
  person: string;
  total: number;
  count: number;
  /** أكبر فئتين بالمبلغ. */
  top_categories: string[];
}

/** الصرف على كل شخص آخر [days] يوم، الأكبر الأول. فاضية = محدش اتسجل له صرف. */
export function spendByPerson(rows: PersonTxn[], nowMs: number, days = SPEND_BY_PERSON_DAYS): PersonSpend[] {
  const since = nowMs - days * 86_400_000;
  const byPerson = new Map<string, { total: number; count: number; cats: Map<string, number> }>();
  for (const r of rows) {
    const person = (r.for_person ?? "").trim();
    if (!person) continue;
    const isExpense = r.txn_kind ? r.txn_kind === "expense" : r.is_expense === true;
    if (!isExpense) continue;
    if (Date.parse(r.created_at) < since) continue;
    const amount = Number(r.amount);
    if (!Number.isFinite(amount) || amount <= 0) continue;
    const p = byPerson.get(person) ?? { total: 0, count: 0, cats: new Map() };
    p.total += amount;
    p.count += 1;
    const cat = (r.category ?? "").trim() || "أخرى";
    p.cats.set(cat, (p.cats.get(cat) ?? 0) + amount);
    byPerson.set(person, p);
  }
  return [...byPerson.entries()]
    .map(([person, p]) => ({
      person,
      total: Math.round(p.total * 100) / 100,
      count: p.count,
      top_categories: [...p.cats.entries()].sort((a, b) => b[1] - a[1]).slice(0, 2).map(([c]) => c),
    }))
    .sort((a, b) => b.total - a.total);
}
