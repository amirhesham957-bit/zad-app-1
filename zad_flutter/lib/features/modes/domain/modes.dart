/// Broke mode ("مفلس لآخر الشهر", `zad_broke_mode`) and the savings
/// challenge (`zad_savings_challenges`) — Kotlin's `BrokeMode.kt` and
/// `SavingsChallenge.kt`, whose arithmetic is shared with the brain
/// (`_shared/brokeMode.ts`, `_shared/savingsChallenge.ts`): the app and the
/// brain must arrive at the same figures.
library;

import 'package:flutter/foundation.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

DateTime? _instant(Object? raw) =>
    raw is String ? DateTime.tryParse(raw)?.toUtc() : null;

/// The broke-mode row.
@immutable
class BrokeMode {
  /// Creates a row.
  const new({
    required this.endsAt,
    this.startedAt,
    this.endedAt,
    this.cashLeft,
    this.dailyCap,
    this.currency,
    this.source = 'app',
  });

  /// Reads a row.
  factory fromJson(Map<String, dynamic> json) => BrokeMode(
    endsAt: _instant(json['ends_at']) ?? DateTime.utc(1970),
    startedAt: _instant(json['started_at']),
    endedAt: _instant(json['ended_at']),
    cashLeft: (json['cash_left'] as num?)?.toDouble(),
    dailyCap: (json['daily_cap'] as num?)?.toDouble(),
    currency: json['currency'] as String?,
    source: json['source'] as String? ?? 'app',
  );

  /// When it runs out on its own.
  final DateTime endsAt;

  /// When it began.
  final DateTime? startedAt;

  /// When the customer closed it, if they did.
  final DateTime? endedAt;

  /// What they said they had.
  final double? cashLeft;

  /// What each day may take — null when nobody said how much there is.
  final double? dailyCap;

  /// The currency of the two figures.
  final String? currency;

  /// Who turned it on: app, voice, chat, telegram.
  final String source;

  /// Running: not closed, and not past its end.
  bool isActiveAt(DateTime now) =>
      endedAt == null && endsAt.isAfter(now.toUtc());

  /// The cached form.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'ends_at': endsAt.toIso8601String(),
    'started_at': startedAt?.toIso8601String(),
    'ended_at': endedAt?.toIso8601String(),
    'cash_left': cashLeft,
    'daily_cap': dailyCap,
    'currency': currency,
    'source': source,
  };
}

/// What turning broke mode on writes.
typedef BrokePlan = ({
  double? cashLeft,
  double? dailyCap,
  int daysLeft,
  DateTime endsAt,
});

/// Kotlin's `BrokeModeMath.plan` = the brain's `brokeModePlan`: the cash the
/// customer typed, else a confirmed available balance, else unknown; split
/// over the days left (1..45); ending at the cycle's end when that is more
/// than an hour away, else after that many days.
BrokePlan brokeModePlan({
  required double? cashLeft,
  required double? available,
  required bool limitConfirmed,
  required int daysLeft,
  required DateTime? cycleEnd,
  required DateTime now,
}) {
  final days = daysLeft.clamp(1, 45);
  final cash = cashLeft != null && cashLeft.isFinite
      ? (cashLeft < 0 ? 0.0 : cashLeft)
      : limitConfirmed && available != null && available.isFinite
      ? (available < 0 ? 0.0 : available)
      : null;
  final byCycle = cycleEnd == null
      ? null
      : DateTime.utc(cycleEnd.year, cycleEnd.month, cycleEnd.day);
  final utcNow = now.toUtc();
  final end =
      byCycle != null && byCycle.isAfter(utcNow.add(const Duration(hours: 1)))
      ? byCycle
      : utcNow.add(Duration(days: days));
  return (
    cashLeft: cash == null ? null : (cash * 100).round() / 100,
    dailyCap: cash == null ? null : (cash / days).floorToDouble(),
    daysLeft: days,
    endsAt: end,
  );
}

/// The active savings challenge.
@immutable
class SavingsChallenge {
  /// Creates a challenge.
  const new({
    required this.id,
    required this.startedOn,
    required this.dailyCap,
    this.lengthDays = 30,
    this.currency,
    this.status = 'active',
    this.daysWon = 0,
    this.daysLost = 0,
    this.streak = 0,
    this.bestStreak = 0,
  });

  /// Reads a row.
  factory fromJson(Map<String, dynamic> json) => SavingsChallenge(
    id: json['id'] as String,
    startedOn: DateTime.parse('${json['started_on']}T00:00:00Z'),
    dailyCap: (json['daily_cap'] as num).toDouble(),
    lengthDays: (json['length_days'] as num?)?.toInt() ?? 30,
    currency: json['currency'] as String?,
    status: json['status'] as String? ?? 'active',
    daysWon: (json['days_won'] as num?)?.toInt() ?? 0,
    daysLost: (json['days_lost'] as num?)?.toInt() ?? 0,
    streak: (json['streak'] as num?)?.toInt() ?? 0,
    bestStreak: (json['best_streak'] as num?)?.toInt() ?? 0,
  );

  /// The row id.
  final String id;

  /// Day one, a civil date at UTC midnight.
  final DateTime startedOn;

  /// Today's ceiling.
  final double dailyCap;

  /// 7..90 days.
  final int lengthDays;

  /// The cap's currency.
  final String? currency;

  /// active, completed, abandoned.
  final String status;

  /// Counted by the server each morning.
  final int daysWon;

  /// Counted by the server each morning.
  final int daysLost;

  /// Days in a row under the cap.
  final int streak;

  /// The longest run so far.
  final int bestStreak;

  /// The cached form.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'started_on':
        '${startedOn.year.toString().padLeft(4, '0')}-'
        '${startedOn.month.toString().padLeft(2, '0')}-'
        '${startedOn.day.toString().padLeft(2, '0')}',
    'daily_cap': dailyCap,
    'length_days': lengthDays,
    'currency': currency,
    'status': status,
    'days_won': daysWon,
    'days_lost': daysLost,
    'streak': streak,
    'best_streak': bestStreak,
  };
}

/// Which day of the challenge [today] is, 1-based, clamped to its length.
int challengeDayIndex(SavingsChallenge c, DateTime today) {
  final t = DateTime.utc(today.year, today.month, today.day);
  return (t.difference(c.startedOn).inDays + 1).clamp(1, c.lengthDays);
}

/// Today's spending by the evaluator's rule: expenses that count toward the
/// budget. [rows] are this account's rows; [isToday] says whether a row's
/// instant falls on today in the account's zone.
double spentToday(
  Iterable<ZadTransaction> rows,
  bool Function(DateTime at) isToday,
) {
  var sum = 0.0;
  for (final t in rows) {
    if (t.kind == TxnKind.expense &&
        t.countsTowardBudget &&
        isToday(t.createdAt)) {
      sum += t.amount.abs();
    }
  }
  return sum;
}

/// The cap Zad proposes — the brain's `suggestChallengeCap`: 80% of the
/// last 30 days' daily average, else 90% of today's allowance, else none.
double? suggestChallengeCap({
  required double? avgDailySpend,
  required double? dailyAllowanceLeft,
}) {
  if (avgDailySpend != null && avgDailySpend > 0) {
    final v = (avgDailySpend * 0.8).round();
    return (v < 1 ? 1 : v).toDouble();
  }
  if (dailyAllowanceLeft != null && dailyAllowanceLeft > 0) {
    final v = (dailyAllowanceLeft * 0.9).floorToDouble();
    return v < 1 ? 1 : v;
  }
  return null;
}
