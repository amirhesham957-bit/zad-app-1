/// A fixed obligation — rent, an instalment, a debt, school fees, a utility
/// bill: one row of `zad_obligations`.
///
/// These are what the budget's "محجوز" is made of, alongside subscriptions:
/// `zad_budget_state()` reserves every active, confirmed obligation falling
/// due before the period ends. So a row this client writes is marked
/// confirmed, as Kotlin's `addObligation` does — an unconfirmed one would be
/// on screen and missing from the figure.
library;

import 'package:flutter/foundation.dart';
import 'package:zad/core/money/money.dart';

/// What an obligation is. The wire values are the table's CHECK constraint.
enum ObligationKind {
  /// إيجار.
  rent('rent', 'إيجار'),

  /// قسط.
  installment('installment', 'قسط'),

  /// دين.
  debt('debt', 'دين'),

  /// مصاريف دراسية.
  tuition('tuition', 'مصاريف دراسية'),

  /// فاتورة مرافق.
  utility('utility', 'فاتورة مرافق'),

  /// أخرى.
  other('other', 'أخرى');

  new(this.wire, this.label);

  /// The stored value.
  final String wire;

  /// What the customer reads.
  final String label;

  /// Reads a stored value; anything unknown is [other].
  static ObligationKind fromWire(String? wire) => ObligationKind.values
      .firstWhere((k) => k.wire == wire, orElse: () => ObligationKind.other);
}

/// How often it falls due. The wire values are the table's CHECK constraint.
enum Recurrence {
  /// شهري.
  monthly('monthly', 'شهري', 1),

  /// ربع سنوي.
  quarterly('quarterly', 'ربع سنوي', 3),

  /// سنوي.
  yearly('yearly', 'سنوي', 12),

  /// مرة واحدة.
  once('once', 'مرة واحدة', 0);

  new(this.wire, this.label, this.months);

  /// The stored value.
  final String wire;

  /// What the customer reads.
  final String label;

  /// Months between two due dates; zero for a one-off.
  final int months;

  /// Reads a stored value; anything unknown is [monthly], the column default.
  static Recurrence fromWire(String? wire) => Recurrence.values.firstWhere(
    (r) => r.wire == wire,
    orElse: () => Recurrence.monthly,
  );
}

/// One obligation.
@immutable
class Obligation {
  /// Creates an obligation.
  const new({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    this.kind = ObligationKind.rent,
    this.dueDay,
    this.dueDate,
    this.recurrence = Recurrence.monthly,
    this.autoDetected = false,
    this.confirmed = true,
    this.active = true,
    this.createdAt,
    this.isPending = false,
  });

  /// Reads a row, from the server or the cache.
  factory fromJson(Map<String, dynamic> json) => Obligation(
    id: json['id'] as String,
    userId: json['user_id'] as String? ?? '',
    title: ((json['title'] as String?) ?? '').trim(),
    amount: (json['amount'] as num).toDouble(),
    kind: ObligationKind.fromWire(json['kind'] as String?),
    dueDay: (json['due_day'] as num?)?.toInt(),
    dueDate: switch (json['due_date']) {
      final String s when s.length >= 10 => DateTime.utc(
        int.parse(s.substring(0, 4)),
        int.parse(s.substring(5, 7)),
        int.parse(s.substring(8, 10)),
      ),
      _ => null,
    },
    recurrence: Recurrence.fromWire(json['recurrence'] as String?),
    autoDetected: json['auto_detected'] as bool? ?? false,
    confirmed: json['confirmed'] as bool? ?? false,
    active: json['active'] as bool? ?? true,
    createdAt: switch (json['created_at']) {
      final String s => DateTime.parse(s).toUtc(),
      _ => null,
    },
    isPending: json['_pending'] as bool? ?? false,
  );

  /// The row id, decided on the device.
  final String id;

  /// Whose it is. RLS (`user_own_obligations`) requires it to be the caller.
  final String userId;

  /// Its name.
  final String title;

  /// How much, each time.
  final double amount;

  /// What it is.
  final ObligationKind kind;

  /// The day of the month it falls due, for a recurring one.
  final int? dueDay;

  /// The date, for a one-off. A civil date at UTC midnight.
  final DateTime? dueDate;

  /// How often.
  final Recurrence recurrence;

  /// Whether the brain found it rather than the customer.
  final bool autoDetected;

  /// Whether the customer has accepted it — only these are reserved.
  final bool confirmed;

  /// Whether it is still running.
  final bool active;

  /// When the row was made.
  final DateTime? createdAt;

  /// Whether this row is still only local.
  final bool isPending;

  /// The columns written.
  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    'id': id,
    'user_id': userId,
    'title': title,
    'amount': amount.asMoney,
    'kind': kind.wire,
    'due_day': dueDay,
    'due_date': dueDate == null
        ? null
        : '${dueDate!.year.toString().padLeft(4, '0')}-'
              '${dueDate!.month.toString().padLeft(2, '0')}-'
              '${dueDate!.day.toString().padLeft(2, '0')}',
    'recurrence': recurrence.wire,
    'confirmed': confirmed,
    'active': active,
  };

  /// The cached form.
  Map<String, dynamic> toCacheJson() => <String, dynamic>{
    ...toUpsertJson(),
    'auto_detected': autoDetected,
    'created_at': createdAt?.toIso8601String(),
    '_pending': isPending,
  };

  /// A copy with the given fields replaced.
  Obligation copyWith({
    String? title,
    double? amount,
    ObligationKind? kind,
    int? dueDay,
    bool clearDueDay = false,
    Recurrence? recurrence,
    bool? active,
    bool? isPending,
  }) => Obligation(
    id: id,
    userId: userId,
    title: title ?? this.title,
    amount: amount ?? this.amount,
    kind: kind ?? this.kind,
    dueDay: clearDueDay ? null : (dueDay ?? this.dueDay),
    dueDate: dueDate,
    recurrence: recurrence ?? this.recurrence,
    autoDetected: autoDetected,
    // `confirmed` is left at its default, true: saved by the customer is
    // accepted by the customer.
    active: active ?? this.active,
    createdAt: createdAt,
    isPending: isPending ?? this.isPending,
  );
}

/// The next due date on or after [today], or null when there is none — a
/// one-off already past, or a recurring row with no day.
///
/// Kotlin's `BudgetMath.nextDueDate`, step for step: start in this month on
/// the due day (clamped to the month's length) and step by the recurrence
/// until not before today, re-clamping each month. Dates are civil, at UTC
/// midnight; [today] is the account's today, not the device's.
DateTime? nextDueDate(Obligation o, DateTime today) {
  final asOf = DateTime.utc(today.year, today.month, today.day);
  if (o.recurrence == Recurrence.once) {
    final due = o.dueDate;
    if (due == null) return null;
    return due.isBefore(asOf) ? null : due;
  }
  final day = o.dueDay;
  if (day == null) return null;
  var year = asOf.year;
  var month = asOf.month;
  DateTime at(int y, int m) =>
      DateTime.utc(y, m, day.clamp(1, _lengthOf(y, m)));
  var next = at(year, month);
  while (next.isBefore(asOf)) {
    month += o.recurrence.months;
    while (month > 12) {
      month -= 12;
      year++;
    }
    next = at(year, month);
  }
  return next;
}

int _lengthOf(int year, int month) => DateTime.utc(year, month + 1, 0).day;

/// Where an obligation stands, for its card.
enum ObligationStatus {
  /// A one-off already gone by.
  paid('مدفوع'),

  /// Due within a week.
  pending('مستحق'),

  /// Further out, or with no date.
  scheduled('مجدول');

  new(this.label);

  /// The tag's text.
  final String label;
}

/// The card's status, its bar (0..1) and the days to go — Kotlin's
/// `ObligationCard` rules.
({ObligationStatus status, double progress, int? daysUntil}) obligationStanding(
  Obligation o,
  DateTime today,
) {
  final asOf = DateTime.utc(today.year, today.month, today.day);
  final due = nextDueDate(o, asOf);
  final days = due?.difference(asOf).inDays;
  if (days == null) {
    return o.recurrence == Recurrence.once
        ? (status: ObligationStatus.paid, progress: 1, daysUntil: null)
        : (status: ObligationStatus.scheduled, progress: 0, daysUntil: null);
  }
  if (days <= 7) {
    return (
      status: ObligationStatus.pending,
      progress: ((7 - days) / 7).clamp(0, 1).toDouble(),
      daysUntil: days,
    );
  }
  return (
    status: ObligationStatus.scheduled,
    progress: (1 - days / 30).clamp(0, 1).toDouble(),
    daysUntil: days,
  );
}
