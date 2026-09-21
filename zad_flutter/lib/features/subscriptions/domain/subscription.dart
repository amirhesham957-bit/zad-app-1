/// One row of `zad_subscriptions`: a subscription, a bill, an instalment, the
/// rent — anything that comes round again.
///
/// `type` and `category` are data, not display text (CLAUDE.md i18n rule): the
/// Kotlin screen filters on `type` values and on Arabic category strings, the
/// agent's tools write them, and the server's observations group by them.
library;

import 'package:flutter/foundation.dart';
import 'package:zad/features/subscriptions/domain/renewal.dart';

/// The kinds of recurring charge, as `zad_subscriptions.type` stores them.
abstract final class SubscriptionType {
  /// A service: streaming, music, software.
  static const String subscription = 'subscription';

  /// A utility bill: electricity, water, internet.
  static const String utility = 'utility';

  /// A bill the older builds wrote with this name.
  static const String bill = 'bill';

  /// An instalment: Tabby, Tamara, a car loan.
  static const String installment = 'installment';

  /// The rent.
  static const String rent = 'rent';
}

/// A recurring charge.
@immutable
class Subscription {
  /// Creates a subscription.
  const new({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    this.renewalDate,
    this.dueDay,
    this.billingCycle,
    this.category,
    this.type = SubscriptionType.subscription,
    this.provider,
    this.isActive = true,
    this.autoDeduct = false,
    this.isPending = false,
  });

  /// Reads a row, from the server or the cache.
  factory fromJson(Map<String, dynamic> json) => Subscription(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    title: (json['title'] as String?) ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    renewalDate: json['renewal_date'] as String?,
    dueDay: (json['due_day'] as num?)?.toInt(),
    billingCycle: json['billing_cycle'] as String?,
    category: json['category'] as String?,
    type: (json['type'] as String?) ?? SubscriptionType.subscription,
    provider: json['provider'] as String?,
    isActive: json['is_active'] as bool? ?? true,
    autoDeduct: json['auto_deduct'] as bool? ?? false,
    isPending: json['_pending'] as bool? ?? false,
  );

  /// The row id, generated on the device so the cache, the outbox entry and
  /// the server row share it.
  final String id;

  /// The owner.
  final String userId;

  /// What the customer calls it.
  final String title;

  /// What one charge costs, in the account's currency.
  final double amount;

  /// The renewal date as stored. Free text on the server — old rows hold
  /// `'30 مارس'` and `'20'` — so it is kept as text and read through
  /// [nextRenewal], never parsed here.
  final String? renewalDate;

  /// The day of the month, when the row carries one.
  final int? dueDay;

  /// The billing cycle as stored, kept verbatim so a row written as `ANNUAL`
  /// is not rewritten just by being read.
  final String? billingCycle;

  /// The customer's category, free text.
  final String? category;

  /// One of [SubscriptionType].
  final String type;

  /// Who charges it.
  final String? provider;

  /// Whether it is still running. Only active rows are reserved.
  final bool isActive;

  /// Whether the bank takes it without the customer doing anything.
  final bool autoDeduct;

  /// Whether a write of this row is still queued.
  final bool isPending;

  /// The cycle, read the way the server reads it.
  BillingCycle get cycle => BillingCycle.fromWire(billingCycle);

  /// The next renewal on or after [today], as the budget will count it.
  DateTime? nextRenewalFrom(DateTime today) => nextRenewal(
    renewalDate: renewalDate,
    dueDay: dueDay,
    billingCycle: billingCycle,
    asOf: today,
  );

  /// What it costs per month.
  double get monthlyCost => monthlyEquivalent(amount, cycle);

  /// A copy with the given fields replaced.
  Subscription copyWith({
    String? title,
    double? amount,
    String? renewalDate,
    int? dueDay,
    String? billingCycle,
    String? category,
    String? type,
    String? provider,
    bool? isActive,
    bool? autoDeduct,
  }) => Subscription(
    id: id,
    userId: userId,
    title: title ?? this.title,
    amount: amount ?? this.amount,
    renewalDate: renewalDate ?? this.renewalDate,
    dueDay: dueDay ?? this.dueDay,
    billingCycle: billingCycle ?? this.billingCycle,
    category: category ?? this.category,
    type: type ?? this.type,
    provider: provider ?? this.provider,
    isActive: isActive ?? this.isActive,
    autoDeduct: autoDeduct ?? this.autoDeduct,
    isPending: isPending,
  );

  /// The same row, marked queued or settled.
  Subscription markPending({required bool pending}) => Subscription(
    id: id,
    userId: userId,
    title: title,
    amount: amount,
    renewalDate: renewalDate,
    dueDay: dueDay,
    billingCycle: billingCycle,
    category: category,
    type: type,
    provider: provider,
    isActive: isActive,
    autoDeduct: autoDeduct,
    isPending: pending,
  );

  /// What goes up.
  ///
  /// Not `source`: new rows take the column default, `user`, and an existing
  /// row written by the agent must not be relabelled as the customer's by an
  /// edit. Not `created_at`: the server's.
  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    'id': id,
    'user_id': userId,
    'title': title,
    'amount': amount,
    'renewal_date': renewalDate,
    'due_day': dueDay,
    'billing_cycle': billingCycle,
    'category': category,
    'type': type,
    'provider': provider,
    'is_active': isActive,
    'auto_deduct': autoDeduct,
  };

  /// What the cache holds.
  Map<String, dynamic> toCacheJson() => <String, dynamic>{
    ...toUpsertJson(),
    '_pending': isPending,
  };
}

/// What paying one instalment does to the title and whether the plan is over.
///
/// The Kotlin convention, kept so both clients count down the same rows: an
/// instalment titled `"جهاز (3 أقساط)"` becomes `"جهاز (2 أقساط)"` when one is
/// paid, and the last one drops the count and ends the plan.
({String title, bool stillRunning}) afterInstalmentPaid(String title) {
  final match = _instalments.firstMatch(title);
  if (match == null) return (title: title, stillRunning: true);

  final remaining = int.tryParse(match.group(1)!) ?? 1;
  if (remaining > 1) {
    return (
      title: title.replaceFirst(match.group(0)!, '(${remaining - 1} أقساط)'),
      stillRunning: true,
    );
  }
  return (
    title: title.replaceFirst(match.group(0)!, '').trim(),
    stillRunning: false,
  );
}

/// `ZadViewModel.markSubscriptionAsPaid`'s pattern, case-insensitive.
final RegExp _instalments = RegExp(
  r'\((\d+)\s*(?:أقساط|قسط|installments?)\)',
  caseSensitive: false,
);

/// The spending category a paid charge is booked under.
///
/// One of the eleven standard categories, never the subscription's own
/// free-text one. The Kotlin app books the row's category — `ترفيه`, or
/// `اشتراكات` without the article — which is not a bucket anything reads, so
/// the money lands in an orphan category. The customer's own category wins
/// only when it already is a standard one.
String categoryForCharge(Subscription sub, List<String> standard) {
  final own = sub.category;
  if (own != null && standard.contains(own)) return own;
  return switch (sub.type) {
    SubscriptionType.utility ||
    SubscriptionType.bill ||
    SubscriptionType.rent => 'الفواتير',
    SubscriptionType.installment => 'الأقساط',
    _ => 'الاشتراكات',
  };
}
