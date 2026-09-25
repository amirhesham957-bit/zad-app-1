/// Category budgets — Kotlin's `BudgetTracker`: a monthly ceiling per
/// spending category, kept on the device, compared with what the period's
/// expenses in that category add up to.
library;

import 'package:zad/features/transactions/domain/transaction.dart';

/// One category's card.
typedef CategoryLine = ({String category, double budget, double spent});

/// What each category spent across [rows] — expenses only, an empty
/// category counted as "أخرى", as Kotlin groups them.
Map<String, double> spentByCategory(Iterable<ZadTransaction> rows) {
  final out = <String, double>{};
  for (final t in rows) {
    if (t.kind != TxnKind.expense) continue;
    final c = (t.category?.trim().isEmpty ?? true) ? 'أخرى' : t.category!;
    out[c] = (out[c] ?? 0) + t.amount;
  }
  return out;
}

/// The cards to show: every standard category with a budget or some
/// spending, the most spent first. [standard] is the stored-category list.
List<CategoryLine> categoryLines({
  required List<String> standard,
  required Map<String, double> budgets,
  required Map<String, double> spent,
}) {
  return <CategoryLine>[
      for (final c in standard)
        (category: c, budget: budgets[c] ?? 0, spent: spent[c] ?? 0),
    ]
    ..removeWhere((l) => l.budget <= 0 && l.spent <= 0)
    ..sort((a, b) => b.spent.compareTo(a.spent));
}

/// The insight strip under the summary — Kotlin's four tiers on how much of
/// the budget is spent.
({String message, int tier}) budgetInsight({
  required double spent,
  required double budget,
}) {
  final pct = budget > 0 ? (spent / budget * 100).toInt() : 0;
  if (pct >= 100) {
    return (message: 'تجاوزت الميزانية! حاول تقليل المصاريف', tier: 3);
  }
  if (pct >= 85) {
    return (message: 'وصلت لـ $pct% من ميزانيتك. كن حذراً', tier: 2);
  }
  if (pct >= 60) {
    return (message: 'صرفت $pct% من ميزانيتك. أداء جيد', tier: 1);
  }
  return (message: 'رائع! أنت في المسار الصحيح. صرفت $pct% فقط', tier: 0);
}
