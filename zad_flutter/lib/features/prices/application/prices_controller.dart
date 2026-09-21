/// The prices screen's state: the community's cheapest prices, who reports
/// most, and the customer's own reports still on the phone.
///
/// Reading them is a database call, not a model call, so the screen refreshes
/// on open like the pantry does. Reporting is queued.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/money/money.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/market/domain/market.dart';
import 'package:zad/features/prices/data/prices_repository.dart';
import 'package:zad/features/prices/domain/prices.dart';

/// What the prices screen draws.
class PricesView {
  /// Creates a view.
  const new({
    this.market,
    this.city,
    this.lastCity,
    this.snapshot,
    this.leaderboard = const <LeaderboardRow>[],
    this.queued = const <QueuedReport>[],
    this.isRefreshing = false,
    this.error,
  });

  /// The account's market — its currency is what prices are read in.
  final Market? market;

  /// The city the list is filtered to, or null for the whole country.
  final String? city;

  /// The city the customer last reported from, offered as a filter.
  final String? lastCity;

  /// The last cheapest list.
  final CheapestSnapshot? snapshot;

  /// Who reports most.
  final List<LeaderboardRow> leaderboard;

  /// The customer's reports still on the phone.
  final List<QueuedReport> queued;

  /// Whether a fetch is in flight.
  final bool isRefreshing;

  /// Why the last fetch failed.
  final Object? error;

  /// The rows for the chosen filter — none when the cache holds another's.
  List<CheapestPrice> get rows {
    final s = snapshot;
    if (s == null || s.city != city || s.currency != market?.currency) {
      return const <CheapestPrice>[];
    }
    return s.rows;
  }

  /// A copy with the given fields replaced.
  PricesView copyWith({
    String? city,
    bool clearCity = false,
    String? lastCity,
    CheapestSnapshot? snapshot,
    List<LeaderboardRow>? leaderboard,
    List<QueuedReport>? queued,
    bool? isRefreshing,
    Object? error,
    bool clearError = false,
  }) => PricesView(
    market: market,
    city: clearCity ? null : (city ?? this.city),
    lastCity: lastCity ?? this.lastCity,
    snapshot: snapshot ?? this.snapshot,
    leaderboard: leaderboard ?? this.leaderboard,
    queued: queued ?? this.queued,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Holds the prices screen.
class PricesController extends Notifier<PricesView> {
  bool _fetching = false;

  @override
  PricesView build() {
    final repository = ref.read(pricesRepositoryProvider);
    final market = marketFor(
      ref.read(settingsRepositoryProvider).cached()?.country,
    );
    final snapshot = repository.cachedCheapest();
    unawaited(Future<void>.microtask(() => ref.mounted ? refresh() : null));
    return PricesView(
      market: market,
      city: snapshot?.city,
      lastCity: repository.lastCity(),
      snapshot: snapshot,
      leaderboard: repository.cachedLeaderboard(),
      queued: repository.queuedReports(),
    );
  }

  /// Fetches the cheapest list and the leaderboard.
  Future<void> refresh() async {
    final currency = state.market?.currency;
    if (_fetching || !ref.mounted || currency == null) return;
    _fetching = true;
    state = state.copyWith(isRefreshing: true, clearError: true);
    final repository = ref.read(pricesRepositoryProvider);
    try {
      final snapshot = await repository.refreshCheapest(
        currency: currency,
        city: state.city,
      );
      final leaderboard = await repository.refreshLeaderboard(
        currency: currency,
      );
      if (!ref.mounted) return;
      state = state.copyWith(
        snapshot: snapshot,
        leaderboard: leaderboard,
        queued: repository.queuedReports(),
        isRefreshing: false,
      );
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        queued: repository.queuedReports(),
        isRefreshing: false,
        error: error,
      );
    } finally {
      _fetching = false;
    }
  }

  /// Filters to [city], or to the whole country when null.
  Future<void> setCity(String? city) async {
    final place = tidyReportText(city);
    state = place.isEmpty
        ? state.copyWith(clearCity: true)
        : state.copyWith(city: place);
    await refresh();
  }

  /// Queues a report as typed, or says what is wrong with it.
  Future<ReportProblem?> report({
    required String item,
    required String priceText,
    String? store,
    String? city,
  }) async {
    final price = parseMoneyInput(priceText);
    final problem = checkReport(
      item: item,
      price: price,
      store: store,
      city: city,
    );
    if (problem != null) return problem;

    final repository = ref.read(pricesRepositoryProvider);
    await repository.report(
      item: item,
      price: price!,
      currency: state.market?.currency,
      store: store,
      city: city,
    );
    if (ref.mounted) {
      state = state.copyWith(
        queued: repository.queuedReports(),
        lastCity: repository.lastCity(),
      );
    }
    return null;
  }
}

/// The prices screen.
final pricesControllerProvider = NotifierProvider<PricesController, PricesView>(
  PricesController.new,
);
