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

/// Arabic weekday names, Saturday first (the week as the region counts it).
const List<String> kWeekdaysAr = <String>[
  'السبت',
  'الأحد',
  'الاتنين',
  'التلات',
  'الأربع',
  'الخميس',
  'الجمعة',
];

/// The average spent on each weekday over the [weeks] weeks up to [today],
/// Saturday first. «إمتى بتصرف أكتر؟» — the owner asked for behaviour, not
/// only totals (2026-10-01).
List<(String, double)> weekdayAverages(
  Iterable<ZadTransaction> rows, {
  required DateTime today,
  required DateTime Function(DateTime utc) local,
  int weeks = 8,
}) {
  final start = DateTime.utc(
    today.year,
    today.month,
    today.day - weeks * 7 + 1,
  );
  final sums = List<double>.filled(7, 0);
  for (final t in rows) {
    if (!_spent(t)) continue;
    final l = local(t.createdAt);
    final day = DateTime.utc(l.year, l.month, l.day);
    if (day.isBefore(start) || day.isAfter(today)) continue;
    // DateTime.weekday: Monday 1 … Sunday 7; Saturday is 6.
    sums[(day.weekday + 1) % 7] += t.amount;
  }
  return <(String, double)>[
    for (var i = 0; i < 7; i++) (kWeekdaysAr[i], sums[i] / weeks),
  ];
}

/// Where the money goes most: the merchant a bank message named, or the
/// title the customer gave, over [rows]; at most [top].
List<(String, double, int)> topPlaces(
  Iterable<ZadTransaction> rows, {
  int top = 5,
}) {
  final totals = <String, (double, int)>{};
  for (final t in rows) {
    if (!_spent(t)) continue;
    final name =
        ((t.merchantName ?? '').trim().isNotEmpty ? t.merchantName! : t.title)
            .trim();
    if (name.isEmpty) continue;
    final cur = totals[name] ?? (0, 0);
    totals[name] = (cur.$1 + t.amount, cur.$2 + 1);
  }
  final sorted = totals.entries.toList()
    ..sort((a, b) => b.value.$1.compareTo(a.value.$1));
  return <(String, double, int)>[
    for (final e in sorted.take(top)) (e.key, e.value.$1, e.value.$2),
  ];
}

/// Categories that moved most between the 30 days up to [today] and the 30
/// before: (category, this period, the one before), the largest change first.
/// A category new this period is a change too; tiny ones are left out.
List<(String, double, double)> categoryChanges(
  Iterable<ZadTransaction> rows, {
  required DateTime today,
  required DateTime Function(DateTime utc) local,
  int top = 3,
  double minimum = 1,
}) {
  final now = DateTime.utc(today.year, today.month, today.day);
  final cut = now.subtract(const Duration(days: 29));
  final before = cut.subtract(const Duration(days: 30));
  final recent = <String, double>{};
  final earlier = <String, double>{};
  for (final t in rows) {
    if (!_spent(t)) continue;
    final l = local(t.createdAt);
    final day = DateTime.utc(l.year, l.month, l.day);
    final c = (t.category ?? '').trim().isEmpty ? 'أخرى' : t.category!.trim();
    if (!day.isBefore(cut) && !day.isAfter(now)) {
      recent[c] = (recent[c] ?? 0) + t.amount;
    } else if (!day.isBefore(before) && day.isBefore(cut)) {
      earlier[c] = (earlier[c] ?? 0) + t.amount;
    }
  }
  final keys = <String>{...recent.keys, ...earlier.keys};
  final changes = <(String, double, double)>[
    for (final k in keys)
      if ((recent[k] ?? 0) - (earlier[k] ?? 0) case final d
          when d.abs() >= minimum)
        (k, recent[k] ?? 0, earlier[k] ?? 0),
  ]..sort((a, b) => (b.$2 - b.$3).abs().compareTo((a.$2 - a.$3).abs()));
  return changes.take(top).toList();
}
