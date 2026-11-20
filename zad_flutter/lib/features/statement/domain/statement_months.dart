/// What the statement world draws and says, read from the transactions the
/// device holds: the last months' money in and out (the curve), how this
/// month's spending compares with the same days of the last, and the month's
/// money in and out by category (the breakdown).
///
/// Months and days are the account's calendar (its market zone), never the
/// device's.
library;

import 'package:timezone/timezone.dart' as tz;
import 'package:zad/shared/transactions/domain/transaction.dart';

/// One calendar month's totals.
typedef MonthTotals = ({int year, int month, double income, double spent});

/// The last [months] months up to and including the one [now] is in, oldest
/// first; months with no transaction at all are left out, so the curve is
/// drawn through real points only.
List<MonthTotals> monthlyTotals(
  Iterable<ZadTransaction> rows,
  tz.Location zone,
  DateTime now, {
  int months = 6,
}) {
  final here = tz.TZDateTime.from(now.toUtc(), zone);
  final current = here.year * 12 + here.month - 1;
  final income = <int, double>{};
  final spent = <int, double>{};
  for (final t in rows) {
    final d = tz.TZDateTime.from(t.createdAt.toUtc(), zone);
    final key = d.year * 12 + d.month - 1;
    if (key > current || key <= current - months) continue;
    switch (t.kind) {
      case TxnKind.income:
        income[key] = (income[key] ?? 0) + t.amount;
      case TxnKind.expense:
        spent[key] = (spent[key] ?? 0) + t.amount;
      case TxnKind.transfer:
        break;
    }
  }
  final keys = <int>{...income.keys, ...spent.keys}.toList()..sort();
  return <MonthTotals>[
    for (final k in keys)
      (
        year: k ~/ 12,
        month: k % 12 + 1,
        income: income[k] ?? 0,
        spent: spent[k] ?? 0,
      ),
  ];
}

/// How this month's spending so far compares with the same days of the last
/// month: `-0.08` is 8% less. Null when the last month had no spending in
/// those days to compare with.
double? spendingPaceChange(
  Iterable<ZadTransaction> rows,
  tz.Location zone,
  DateTime now,
) {
  final here = tz.TZDateTime.from(now.toUtc(), zone);
  final current = here.year * 12 + here.month - 1;
  var thisMonth = 0.0;
  var lastMonth = 0.0;
  for (final t in rows) {
    if (t.kind != TxnKind.expense) continue;
    final d = tz.TZDateTime.from(t.createdAt.toUtc(), zone);
    if (d.day > here.day) continue;
    final key = d.year * 12 + d.month - 1;
    if (key == current) thisMonth += t.amount;
    if (key == current - 1) lastMonth += t.amount;
  }
  return lastMonth <= 0 ? null : (thisMonth - lastMonth) / lastMonth;
}

/// The month in question: money in, and money out by category, biggest
/// first.
typedef MonthBreakdown = ({double income, List<(String, double)> spent});

/// The breakdown of the month [now] is in.
MonthBreakdown monthBreakdown(
  Iterable<ZadTransaction> rows,
  tz.Location zone,
  DateTime now,
) {
  final here = tz.TZDateTime.from(now.toUtc(), zone);
  var income = 0.0;
  final byCategory = <String, double>{};
  for (final t in rows) {
    final d = tz.TZDateTime.from(t.createdAt.toUtc(), zone);
    if (d.year != here.year || d.month != here.month) continue;
    switch (t.kind) {
      case TxnKind.income:
        income += t.amount;
      case TxnKind.expense:
        // The stored category key, never a label.
        // l10n: data-begin
        final c = (t.category?.trim().isEmpty ?? true) ? 'أخرى' : t.category!;
        // l10n: data-end
        byCategory[c] = (byCategory[c] ?? 0) + t.amount;
      case TxnKind.transfer:
        break;
    }
  }
  final sorted = byCategory.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return (
    income: income,
    spent: <(String, double)>[for (final e in sorted) (e.key, e.value)],
  );
}
