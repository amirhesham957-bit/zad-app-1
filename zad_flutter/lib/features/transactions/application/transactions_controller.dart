/// The transactions list, cache first.
///
/// Same contract as the budget: the first frame draws what is already on the
/// device, and the server is asked afterwards. The list is where that matters
/// most — it is long, it is scrolled, and a spinner over it is a spinner over
/// the thing the user opened the screen to read.
///
/// The period is not a parameter. It is read from the budget, which is the one
/// authority for it, so the list and the card on the home screen can never be
/// reporting two different months. A family keyed on `BudgetPeriod` was the
/// first shape tried and was wrong twice over: the type has no equality, so
/// every rebuild would have made a new family entry, and it would have let the
/// two screens disagree.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/period/budget_period.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

/// What the list screen draws.
class TransactionsView {
  /// Creates a view.
  const new({
    this.rows = const <ZadTransaction>[],
    this.period,
    this.isRefreshing = false,
    this.isStale = false,
    this.error,
  });

  /// The period's rows, newest first.
  final List<ZadTransaction> rows;

  /// The period being shown, or null before the budget has reported one.
  final BudgetPeriod? period;

  /// Whether a fetch is in flight. Never a reason to hide the rows.
  final bool isRefreshing;

  /// Whether what is shown has not been confirmed this session.
  final bool isStale;

  /// The last refresh failure.
  final Object? error;

  /// Whether there is nothing to show.
  bool get isEmpty => rows.isEmpty;

  /// Rows this device wrote that the server has not acknowledged.
  int get pendingCount => rows.where((r) => r.isPending).length;

  /// A copy with the given fields replaced.
  TransactionsView copyWith({
    List<ZadTransaction>? rows,
    BudgetPeriod? period,
    bool? isRefreshing,
    bool? isStale,
    Object? error,
    bool clearError = false,
  }) => TransactionsView(
    rows: rows ?? this.rows,
    period: period ?? this.period,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isStale: isStale ?? this.isStale,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Holds the current period's transactions.
class TransactionsController extends Notifier<TransactionsView> {
  /// How long a re-entry reuses what it already fetched.
  ///
  /// The same five minutes the budget uses, for the same measured reason: an
  /// unguarded fetch on every screen entry is what ran one account to 96% of a
  /// 200,000-token daily cap on the Kotlin app.
  static const Duration cooldown = Duration(minutes: 5);

  DateTime? _lastFetch;
  bool _fetching = false;

  @override
  TransactionsView build() {
    // Watched, so a new period — payday arriving, or the first snapshot
    // landing — rebuilds this with that period's rows rather than the last
    // one's. A list showing last month's spending under this month's heading
    // is worse than one showing nothing.
    final period = ref.watch(
      budgetControllerProvider.select((v) => v.snapshot?.periodOrNull),
    );

    if (period == null) return const TransactionsView();

    // Synchronous. This is the whole claim of the screen.
    final cached = ref
        .read(transactionsRepositoryProvider)
        .cachedPeriod(period);

    unawaited(Future<void>.microtask(() => ref.mounted ? refresh() : null));

    return TransactionsView(
      rows: cached,
      period: period,
      isStale: cached.isNotEmpty,
    );
  }

  /// Fetches, unless it is inside the cooldown and [force] is false.
  Future<void> refresh({bool force = false}) async {
    final period = state.period;
    if (_fetching || period == null || !ref.mounted) return;

    final now = ref.read(nowProvider)();
    final last = _lastFetch;
    if (!force && last != null && now.difference(last) < cooldown) return;

    _fetching = true;
    state = state.copyWith(isRefreshing: true, clearError: true);

    try {
      final rows = await ref
          .read(transactionsRepositoryProvider)
          .refreshPeriod(period);
      if (!ref.mounted) return;
      _lastFetch = now;
      state = TransactionsView(rows: rows, period: period);
    } on Object catch (error) {
      if (!ref.mounted) return;
      // The rows stay. A failed refresh marks them; it never replaces a
      // readable list with an error page.
      state = state.copyWith(isRefreshing: false, isStale: true, error: error);
    } finally {
      _fetching = false;
    }
  }

  /// Re-reads the cache without touching the network.
  ///
  /// For after a local write: the row is already in Hive, and the list should
  /// show it in the same frame the user saves it.
  void reloadFromCache() {
    final period = state.period;
    if (!ref.mounted || period == null) return;
    state = state.copyWith(
      rows: ref.read(transactionsRepositoryProvider).cachedPeriod(period),
    );
  }
}

/// The current period's transactions.
final transactionsControllerProvider =
    NotifierProvider<TransactionsController, TransactionsView>(
      TransactionsController.new,
    );
