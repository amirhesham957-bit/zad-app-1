/// The home screen's state: cache first, server second.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/budget/domain/budget_snapshot.dart';

/// What the screen has to draw with.
class BudgetView {
  /// Creates a view.
  const new({
    this.snapshot,
    this.pendingSpend = 0,
    this.isRefreshing = false,
    this.isStale = false,
    this.error,
  });

  /// The server's last answer, or null if it has never given one.
  final BudgetSnapshot? snapshot;

  /// Expenses written on this device that the server has not seen yet.
  final double pendingSpend;

  /// Whether a refresh is in flight. Never a reason to hide the figures.
  final bool isRefreshing;

  /// Whether what is on screen has not been confirmed — either the refresh has
  /// not landed yet, or it failed, or the cached answer is about a cycle that
  /// has already ended.
  final bool isStale;

  /// The last refresh failure, if the user should be told.
  final Object? error;

  /// Whether there is anything to show at all.
  bool get hasFigures => snapshot?.hasBudget ?? false;

  /// The figure to lead with, with queued spending already taken off.
  ///
  /// Subtracting the pending rows is the client's one liberty with the server's
  /// number, and it is the right one: a user who just recorded a purchase
  /// expects the balance to move, and telling them it has not because a request
  /// is queued would be describing the network, not their money.
  double? get spendable {
    final base = snapshot?.spendable;
    return base == null ? null : base - pendingSpend;
  }

  /// A copy with the given fields replaced.
  BudgetView copyWith({
    BudgetSnapshot? snapshot,
    double? pendingSpend,
    bool? isRefreshing,
    bool? isStale,
    Object? error,
    bool clearError = false,
  }) => BudgetView(
    snapshot: snapshot ?? this.snapshot,
    pendingSpend: pendingSpend ?? this.pendingSpend,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isStale: isStale ?? this.isStale,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Holds the home screen's budget.
class BudgetController extends Notifier<BudgetView> {
  /// How long a screen re-entry reuses what it already fetched.
  ///
  /// This guard is here because of a measured bill, not a hunch: on the Kotlin
  /// app, screen-entry refreshes ran unguarded and one user reached 96% of a
  /// 200,000-token daily cap in a day. The same shape — `build` fires a fetch,
  /// every return to the tab rebuilds — would do the same here.
  ///
  /// First open fetches. A return inside the window draws the figures already
  /// in hand and calls nothing. A pull-to-refresh always fetches.
  static const Duration cooldown = Duration(minutes: 5);

  DateTime? _lastFetch;
  bool _fetching = false;

  @override
  BudgetView build() {
    final budgets = ref.watch(budgetRepositoryProvider);
    final now = ref.read(nowProvider)();

    final cached = budgets.cached();
    final view = BudgetView(
      snapshot: cached,
      pendingSpend: _pendingSpend(cached),
      // Anything from the cache is unconfirmed until this session has heard
      // from the server — and doubly so if its cycle has already ended.
      isStale: cached != null && !cached.coversNow(now),
    );

    // Kick the refresh after the first frame rather than awaiting it, so the
    // cached figures are on screen in the same frame the screen appears.
    //
    // The microtask outlives this build: a sign-out, a rebuild or a hot reload
    // can dispose the provider while it is still queued, and touching `state`
    // after that throws. Every gap below checks `ref.mounted` for that reason.
    unawaited(Future<void>.microtask(() => ref.mounted ? refresh() : null));

    return view;
  }

  /// Fetches, unless it is inside the cooldown and [force] is false.
  Future<void> refresh({bool force = false}) async {
    if (_fetching || !ref.mounted) return;

    final now = ref.read(nowProvider)();
    final last = _lastFetch;
    if (!force && last != null && now.difference(last) < cooldown) return;

    _fetching = true;
    state = state.copyWith(isRefreshing: true, clearError: true);

    try {
      final snapshot = await ref
          .read(budgetRepositoryProvider)
          .refresh(timeZone: state.snapshot?.timeZone ?? 'UTC');
      if (!ref.mounted) return;
      _lastFetch = now;
      state = BudgetView(
        snapshot: snapshot,
        pendingSpend: _pendingSpend(snapshot),
      );
    } on Object catch (error) {
      if (!ref.mounted) return;
      // The figures stay on screen. A failed refresh is a reason to say the
      // number is not confirmed, never a reason to replace it with an error.
      state = state.copyWith(isRefreshing: false, isStale: true, error: error);
    } finally {
      _fetching = false;
    }
  }

  /// Recomputes the pending adjustment after a local write.
  void recomputePending() {
    if (!ref.mounted) return;
    state = state.copyWith(pendingSpend: _pendingSpend(state.snapshot));
  }

  double _pendingSpend(BudgetSnapshot? snapshot) {
    if (snapshot == null) return 0;

    final start = snapshot.cycleStart;
    final end = snapshot.cycleEnd;

    return ref
        .read(transactionsRepositoryProvider)
        .allCached()
        .where(
          (t) =>
              t.isPending &&
              t.isExpense &&
              t.countsTowardBudget &&
              // Only this cycle's. A row still queued from a cycle the server
              // has already closed was never counted in these figures, but it
              // is not part of them either.
              (start == null || !t.createdAt.isBefore(start)) &&
              (end == null || t.createdAt.isBefore(end)),
        )
        .fold<double>(0, (sum, t) => sum + t.amount);
  }
}

/// The home screen's budget.
final budgetControllerProvider = NotifierProvider<BudgetController, BudgetView>(
  BudgetController.new,
);
