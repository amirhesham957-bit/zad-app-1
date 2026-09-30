/// What `zad_budget_state()` says about an account, as a Dart object.
///
/// This is read from the server and **not** recomputed here. There is a
/// migration called `single_budget_authority`, and that is what it means: the
/// budget is one function's answer. A client that re-derived it from its own
/// cached rows would be a second authority, and the day the two disagree the
/// user is told two different numbers by the same company.
///
/// So the offline story is caching this answer, not reproducing it. What the
/// client may do on top is say that the answer is not confirmed, and subtract
/// what it knows it has queued — both of which are marked as such on screen.
library;

import 'package:zad/core/period/budget_period.dart';

/// How fast the account is spending relative to the cycle.
enum BudgetThreat {
  /// On track.
  safe,

  /// Ahead of pace.
  watch,

  /// Well ahead of pace.
  danger,

  /// Past the opening balance.
  over,

  /// Not knowable — usually because no limit has been confirmed.
  unknown;

  /// Reads `threat` out of the jsonb.
  static BudgetThreat fromWire(String? value) => switch (value) {
    'SAFE' => safe,
    'WATCH' => watch,
    'DANGER' => danger,
    'OVER' => over,
    _ => unknown,
  };
}

/// One reading of the budget.
class BudgetSnapshot {
  /// Creates a snapshot.
  const new({
    required this.userId,
    required this.currency,
    required this.timeZone,
    required this.spent,
    required this.income,
    required this.committed,
    required this.daysLeft,
    required this.cycleLengthDays,
    required this.threat,
    required this.unverifiedCount,
    required this.computedAt,
    this.available,
    this.remaining,
    this.openingBalance,
    this.limitConfirmed = false,
    this.cycleStart,
    this.cycleEnd,
  });

  /// Reads the jsonb `zad_budget_state()` returns.
  factory fromJson(Map<String, dynamic> json) => BudgetSnapshot(
    userId: json['user_id'] as String? ?? '',
    currency: json['currency'] as String? ?? '',
    timeZone: json['timezone'] as String? ?? 'UTC',
    spent: _num(json['spent']) ?? 0,
    income: _num(json['income']) ?? 0,
    committed: _num(json['committed']) ?? 0,
    daysLeft: (json['days_left'] as num?)?.toInt() ?? 0,
    cycleLengthDays: (json['cycle_length_days'] as num?)?.toInt() ?? 0,
    threat: BudgetThreat.fromWire(json['threat'] as String?),
    unverifiedCount: (json['unverified_count'] as num?)?.toInt() ?? 0,
    computedAt: switch (json['computed_at']) {
      final String s => DateTime.parse(s).toUtc(),
      _ => DateTime.now().toUtc(),
    },
    available: _num(json['available']),
    remaining: _num(json['remaining']),
    openingBalance: _num(json['opening_balance']),
    limitConfirmed: json['limit_confirmed'] as bool? ?? false,
    cycleStart: _date(json['cycle_start']),
    cycleEnd: _date(json['cycle_end']),
  );

  /// Whose budget this is.
  final String userId;

  /// The account's currency.
  final String currency;

  /// The IANA zone the server counted the cycle in.
  final String timeZone;

  /// Spent this cycle, or since the balance anchor when one is set.
  final double spent;

  /// Received this cycle.
  final double income;

  /// Obligations and subscriptions falling due before the cycle ends.
  final double committed;

  /// Days left in the cycle, as the **server** counts them.
  final int daysLeft;

  /// The cycle's length in days, as the server counts it.
  final int cycleLengthDays;

  /// The pace reading.
  final BudgetThreat threat;

  /// Transactions this cycle the user has not confirmed.
  final int unverifiedCount;

  /// When the server computed this.
  final DateTime computedAt;

  /// What is actually spendable: `remaining - committed`.
  ///
  /// Null when no limit has been confirmed. The server refuses to guess a
  /// budget, and so must this — see [hasBudget].
  final double? available;

  /// The balance: opening + income - spent. Null for the same reason.
  final double? remaining;

  /// The confirmed `monthly_limit` the cycle opened with.
  final double? openingBalance;

  /// Whether the user has confirmed their limit.
  final bool limitConfirmed;

  /// The cycle's first day, as the server computes it.
  final DateTime? cycleStart;

  /// The day after the cycle's last, as the server computes it.
  final DateTime? cycleEnd;

  /// Whether there is a budget to report at all.
  ///
  /// When this is false the card must not show a figure. `remaining` is null
  /// precisely so a client cannot print a confident zero at somebody who never
  /// told us what they earn.
  bool get hasBudget => remaining != null;

  /// The figure to lead with: what can be spent, not what is left.
  ///
  /// Rent that has not gone out yet is still not yours to spend. Falls back to
  /// [remaining] only if the server gave one without an `available`.
  double? get spendable => available ?? remaining;

  /// Whether this reading still describes the cycle that [at] falls in.
  ///
  /// A cached snapshot outlives its cycle. Payday arrives, the figures reset on
  /// the server, and a device that has not synced since is holding last month's
  /// answer — which is not merely stale but about the wrong month. This is what
  /// the client can decide on its own, offline, without a second budget
  /// authority: not what the numbers are, only whether they are still about
  /// now.
  bool coversNow(DateTime at) {
    final end = cycleEnd;
    if (end == null) return false;
    // cycle_end is the day *after* the last, as a civil date in [timeZone].
    // Comparing instants would need the zone's rules; comparing the civil date
    // the account is on is enough to catch a rollover and cannot be off by more
    // than the hours either side of midnight.
    final today = at.toUtc();
    return today.isBefore(end.add(const Duration(days: 1)));
  }

  /// This reading's cycle as a [BudgetPeriod], or null when the server gave
  /// no range.
  ///
  /// Built from the server's own dates rather than recomputed, so every screen
  /// reporting these figures counts the same days — see
  /// `BudgetPeriod.fromServer`.
  BudgetPeriod? get periodOrNull {
    final start = cycleStart;
    final end = cycleEnd;
    if (start == null || end == null) return null;
    return BudgetPeriod.fromServer(
      cycleStart: start,
      cycleEnd: end,
      timeZone: timeZone,
    );
  }

  /// Round-trips through the cache.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'user_id': userId,
    'currency': currency,
    'timezone': timeZone,
    'spent': spent,
    'income': income,
    'committed': committed,
    'days_left': daysLeft,
    'cycle_length_days': cycleLengthDays,
    'threat': threat.name.toUpperCase(),
    'unverified_count': unverifiedCount,
    'computed_at': computedAt.toIso8601String(),
    'available': available,
    'remaining': remaining,
    'opening_balance': openingBalance,
    'limit_confirmed': limitConfirmed,
    'cycle_start': cycleStart?.toIso8601String().split('T').first,
    'cycle_end': cycleEnd?.toIso8601String().split('T').first,
  };
}

double? _num(Object? value) => (value as num?)?.toDouble();

DateTime? _date(Object? value) => switch (value) {
  final String s => DateTime.parse('${s.split('T').first}T00:00:00Z'),
  _ => null,
};
