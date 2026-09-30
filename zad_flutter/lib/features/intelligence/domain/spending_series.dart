/// The numbers behind the brain screen's charts: spending per day, and per
/// category. Pure — the screen passes the rows, the day and the zone.
library;

import 'package:zad/shared/transactions/domain/transaction.dart';

/// Whether [t] is money spent that counts: an expense, not a transfer.
bool _spent(ZadTransaction t) =>
    t.isExpense && t.kind != TxnKind.transfer && t.amount > 0;

/// Spending on each of the last [days] days up to [today] (a civil date),
/// oldest first. [local] turns a UTC instant into the account's civil time.
List<(DateTime, double)> dailySpend(
  Iterable<ZadTransaction> rows, {
  required DateTime today,
  required DateTime Function(DateTime utc) local,
  int days = 14,
}) {
  final start = DateTime.utc(today.year, today.month, today.day - days + 1);
  final totals = <DateTime, double>{
    for (var i = 0; i < days; i++)
      DateTime.utc(start.year, start.month, start.day + i): 0,
  };
  for (final t in rows) {
    if (!_spent(t)) continue;
    final l = local(t.createdAt);
    final day = DateTime.utc(l.year, l.month, l.day);
    if (totals.containsKey(day)) totals[day] = totals[day]! + t.amount;
  }
  return <(DateTime, double)>[for (final e in totals.entries) (e.key, e.value)];
}

/// Spending per category, most first; past [top] they are summed as «أخرى».
/// A row with no category counts as «أخرى» too.
List<(String, double)> categoryShares(
  Iterable<ZadTransaction> rows, {
  int top = 5,
}) {
  final totals = <String, double>{};
  for (final t in rows) {
    if (!_spent(t)) continue;
    final c = (t.category ?? '').trim();
    final key = c.isEmpty ? 'أخرى' : c;
    totals[key] = (totals[key] ?? 0) + t.amount;
  }
  final sorted = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final head = sorted.where((e) => e.key != 'أخرى').take(top).toList();
  final rest = sorted
      .where((e) => !head.contains(e))
      .fold<double>(0, (sum, e) => sum + e.value);
  return <(String, double)>[
    for (final e in head) (e.key, e.value),
    if (rest > 0) ('أخرى', rest),
  ];
}
