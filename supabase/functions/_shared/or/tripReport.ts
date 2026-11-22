// تقرير مصاريف الرحلة (م٧.٧): بيجمع المصاريف حسب الفئة، ويرتّبها من الأكبر للأصغر، ويطلّع أعلى N فئة مع نسبتها من الإجمالي.
// الإجمالي بيحسب كل الفئات حتى لو الناتج اتقص لأعلى N. المبالغ السالبة بتتجاهل.
// دالة نقية: مافيش I/O.

export interface TripSpend {
  category: string;
  amount: number;
}

export interface TripCategoryRow {
  category: string;
  amount: number;
  share: number;
}

export interface TripReport {
  total: number;
  byCategory: TripCategoryRow[];
}

/** تقريب لرقمين عشريين (جنيه وقروش). */
function round2(value: number): number {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

/** تقريب لتلات أرقام عشرية (للنسبة). */
function round3(value: number): number {
  return Math.round((value + Number.EPSILON) * 1000) / 1000;
}

export function tripReport(spends: readonly TripSpend[], topN = 3): TripReport {
  // نجمع الأول بالفئة. المبلغ السالب (أو اللي مش رقم) بيتجاهل.
  const sums = new Map<string, number>();
  for (const spend of spends) {
    if (!(spend.amount >= 0)) continue;
    sums.set(spend.category, (sums.get(spend.category) ?? 0) + spend.amount);
  }

  // نقرّب كل فئة الأول، والإجمالي بيتحسب من الأرقام المقرّبة عشان يتطابق مع اللي بيترجع.
  const all = [...sums.entries()].map(([category, raw]) => ({ category, amount: round2(raw) }));
  const total = round2(all.reduce((acc, row) => acc + row.amount, 0));

  // الترتيب: المبلغ تنازلي، ولو متساوي يبقى اسم الفئة تصاعدي.
  all.sort((a, b) => b.amount - a.amount || (a.category < b.category ? -1 : a.category > b.category ? 1 : 0));

  const byCategory = all
    .slice(0, Math.max(0, topN))
    .map((row) => ({
      category: row.category,
      amount: row.amount,
      share: total === 0 ? 0 : round3(row.amount / total),
    }));

  return { total, byCategory };
}
