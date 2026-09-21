/// The subscriptions screen's state.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/scan/domain/scanned_receipt.dart';
import 'package:zad/features/subscriptions/data/subscriptions_repository.dart';
import 'package:zad/features/subscriptions/domain/renewal.dart';
import 'package:zad/features/subscriptions/domain/subscription.dart';
import 'package:zad/features/transactions/application/transactions_controller.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

/// What the screen draws.
class SubscriptionsView {
  /// Creates a view.
  const new({
    required this.items,
    required this.today,
    this.isRefreshing = false,
    this.error,
  });

  /// Every row: running ones first, soonest renewal first, then stopped ones.
  final List<Subscription> items;

  /// Today in the account's market zone — the day renewals are counted from.
  final DateTime today;

  /// Whether a read is in flight.
  final bool isRefreshing;

  /// The last failure worth telling the customer about.
  final Object? error;

  /// The running rows.
  Iterable<Subscription> get active => items.where((s) => s.isActive);

  /// What the running rows cost per month, across cycles.
  double get monthlyTotal => active.fold(0, (sum, s) => sum + s.monthlyCost);

  /// A copy with the given fields replaced.
  SubscriptionsView copyWith({
    List<Subscription>? items,
    DateTime? today,
    bool? isRefreshing,
    Object? error,
    bool clearError = false,
  }) => SubscriptionsView(
    items: items ?? this.items,
    today: today ?? this.today,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Holds the recurring charges and writes them.
class SubscriptionsController extends Notifier<SubscriptionsView> {
  /// How long a re-entry reuses what it already fetched.
  static const Duration cooldown = Duration(minutes: 5);

  DateTime? _lastFetch;
  bool _fetching = false;

  @override
  SubscriptionsView build() {
    final today = _today();
    final cached = ref.read(subscriptionsRepositoryProvider).cached();
    unawaited(Future<void>.microtask(() => ref.mounted ? refresh() : null));
    return SubscriptionsView(items: _sorted(cached, today), today: today);
  }

  /// Reads the table, unless inside the cooldown and [force] is false.
  Future<void> refresh({bool force = false}) async {
    if (_fetching || !ref.mounted) return;
    final now = ref.read(nowProvider)();
    final last = _lastFetch;
    if (!force && last != null && now.difference(last) < cooldown) return;

    _fetching = true;
    state = state.copyWith(isRefreshing: true, clearError: true);
    try {
      final items = await ref.read(subscriptionsRepositoryProvider).refresh();
      if (!ref.mounted) return;
      _lastFetch = now;
      final today = _today();
      state = SubscriptionsView(items: _sorted(items, today), today: today);
    } on Object catch (error) {
      if (!ref.mounted) return;
      // The rows on screen stay. A failed read never empties the list.
      state = state.copyWith(isRefreshing: false, error: error);
    } finally {
      _fetching = false;
    }
  }

  /// Adds a charge.
  Future<void> add({
    required String title,
    required double amount,
    required BillingCycle cycle,
    DateTime? renewsOn,
    String? category,
    String type = SubscriptionType.subscription,
    String? provider,
  }) async {
    await ref
        .read(subscriptionsRepositoryProvider)
        .add(
          title: title,
          amount: amount,
          cycle: cycle,
          renewsOn: renewsOn,
          category: category,
          type: type,
          provider: provider,
        );
    _afterWrite();
  }

  /// Saves an edited row.
  Future<void> save(Subscription sub) async {
    await ref.read(subscriptionsRepositoryProvider).update(sub);
    _afterWrite();
  }

  /// Starts or stops a charge.
  Future<void> setActive(Subscription sub, {required bool active}) async {
    await ref
        .read(subscriptionsRepositoryProvider)
        .setActive(sub.id, active: active);
    _afterWrite();
  }

  /// Removes a charge.
  Future<void> remove(Subscription sub) async {
    await ref.read(subscriptionsRepositoryProvider).remove(sub.id);
    _afterWrite();
  }

  /// Records that [sub] was paid: an expense for the amount, and the renewal
  /// moved past the one just paid, so the budget stops reserving it.
  ///
  /// Returns what was paid, or null when the row is gone.
  Future<PaidRenewal?> markPaid(Subscription sub) async {
    final userId = ref.read(signedInUserIdProvider)();
    if (userId == null || userId.isEmpty) return null;

    final paid = await ref
        .read(subscriptionsRepositoryProvider)
        .markPaid(sub.id, today: state.today);
    if (paid == null) return null;

    await ref
        .read(transactionsRepositoryProvider)
        .record(
          (id) => ZadTransaction.expense(
            id: id,
            userId: userId,
            amount: sub.amount,
            // The title as it was, so "(3 أقساط)" says which instalment.
            title: sub.title,
            createdAt: ref.read(nowProvider)(),
            // A recurring charge is a card or a direct debit far more often
            // than cash; the customer can change it on the row.
            wallet: Wallet.card,
            category: categoryForCharge(sub, kStandardCategories),
            merchantName: sub.provider,
          ),
        );
    if (!ref.mounted) return paid;

    // The two screens already showing money. Without these the expense is in
    // Hive and neither the list nor the balance knows it.
    ref.read(transactionsControllerProvider.notifier).reloadFromCache();
    ref.read(budgetControllerProvider.notifier).recomputePending();

    _afterWrite();
    return paid;
  }

  /// Re-reads the cache onto the screen, then sends what was queued.
  void _afterWrite() {
    if (!ref.mounted) return;
    final today = _today();
    state = state.copyWith(
      items: _sorted(ref.read(subscriptionsRepositoryProvider).cached(), today),
      today: today,
    );
    unawaited(_deliver());
  }

  /// Sends the queue, then asks for a budget that knows about the change.
  ///
  /// These rows are what `committed` is made of, so the figure on the home
  /// screen is stale the moment one changes — but only once the change has
  /// landed: asking before would fetch the old reservation again.
  Future<void> _deliver() async {
    final outbox = ref.read(outboxProvider);
    try {
      await outbox.flush();
    } on Object {
      return;
    }
    if (!ref.mounted) return;

    final stillQueued = outbox
        .entries(includeDead: false)
        .any(
          (e) =>
              e.kind == OutboxKind.upsertSubscription ||
              e.kind == OutboxKind.deleteSubscription,
        );
    if (stillQueued) return;

    final today = _today();
    state = state.copyWith(
      items: _sorted(ref.read(subscriptionsRepositoryProvider).cached(), today),
      today: today,
    );
    unawaited(ref.read(budgetControllerProvider.notifier).refresh(force: true));
  }

  /// Today in the account's market zone, as a civil date — the day the server
  /// counts renewals from, never the device's.
  DateTime _today() {
    final now = ref.read(nowProvider)();
    final zone = tz.getLocation(ref.read(accountTimeZoneProvider));
    final local = tz.TZDateTime.from(now.toUtc(), zone);
    return DateTime.utc(local.year, local.month, local.day);
  }

  /// Running first, soonest renewal first; a row with no schedule after the
  /// dated ones; stopped rows last.
  static List<Subscription> _sorted(List<Subscription> items, DateTime today) {
    int rank(Subscription s) => s.isActive ? 0 : 1;
    return <Subscription>[...items]..sort((a, b) {
      final byActive = rank(a).compareTo(rank(b));
      if (byActive != 0) return byActive;
      final na = a.nextRenewalFrom(today);
      final nb = b.nextRenewalFrom(today);
      if (na == null && nb == null) return a.title.compareTo(b.title);
      if (na == null) return 1;
      if (nb == null) return -1;
      final byDate = na.compareTo(nb);
      return byDate != 0 ? byDate : a.title.compareTo(b.title);
    });
  }
}

/// The recurring charges.
final subscriptionsControllerProvider =
    NotifierProvider<SubscriptionsController, SubscriptionsView>(
      SubscriptionsController.new,
    );
