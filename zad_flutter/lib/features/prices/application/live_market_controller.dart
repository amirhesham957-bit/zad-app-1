/// Kotlin's live market strip state (`ZadViewModel.refreshLiveMarketPrices`,
/// `loadCachedMarketPrices`): the last fetched prices per market on this
/// device, and a fetch through `fetch_live_market_prices`.
///
/// That action is a web-search model call, so — the owner's rule for this
/// port — it runs only when the customer taps refresh. Opening home shows the
/// cached strip (or Kotlin's approximate staples) and calls nothing.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/market/domain/market.dart';

/// Kotlin's `MarketPriceItem`.
@immutable
class MarketPriceItem {
  /// Creates an item.
  const new({
    required this.symbol,
    required this.price,
    this.unit = '',
    this.changePercent = 0,
    this.trend = 'flat',
  });

  /// From the action's JSON or the cache.
  static MarketPriceItem? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final symbol = raw['symbol'];
    final price = raw['price'];
    if (symbol is! String || price is! num) return null;
    return MarketPriceItem(
      symbol: symbol,
      price: price.toDouble(),
      unit: raw['unit'] as String? ?? '',
      changePercent: (raw['change_percent'] as num?)?.toDouble() ?? 0,
      trend: raw['trend'] as String? ?? 'flat',
    );
  }

  /// The item's name.
  final String symbol;

  /// Its price.
  final double price;

  /// Per what.
  final String unit;

  /// Change, in percent.
  final double changePercent;

  /// `up`, `down` or `flat`.
  final String trend;

  /// For the cache.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'symbol': symbol,
    'price': price,
    'unit': unit,
    'change_percent': changePercent,
    'trend': trend,
  };
}

/// Kotlin's `LiveFetchState`.
enum LiveFetchState {
  /// Never asked in this session.
  idle,

  /// Asking.
  loading,

  /// Answered.
  fetched,

  /// Failed.
  error,
}

/// The strip's state.
@immutable
class LiveMarketView {
  /// Creates a view.
  const new({required this.prices, required this.fetchState});

  /// Real prices, or empty.
  final List<MarketPriceItem> prices;

  /// Where the last fetch stands.
  final LiveFetchState fetchState;
}

/// Reads the cache, and fetches on request.
class LiveMarketController extends Notifier<LiveMarketView> {
  @override
  LiveMarketView build() {
    final country = ref.watch(settingsRepositoryProvider).cached()?.country;
    return LiveMarketView(
      prices: _loadCache(country),
      fetchState: LiveFetchState.idle,
    );
  }

  String _cacheKey(String? country) =>
      'live_market_prices_${country ?? 'unknown'}';

  List<MarketPriceItem> _loadCache(String? country) {
    try {
      final raw = ref.read(localStoreProvider).device.get(_cacheKey(country));
      if (raw == null) return const <MarketPriceItem>[];
      final list = jsonDecode(raw);
      if (list is! List) return const <MarketPriceItem>[];
      return list.map(MarketPriceItem.tryParse).nonNulls.toList();
    } on Object {
      return const <MarketPriceItem>[];
    }
  }

  /// Kotlin's `refreshLiveMarketPrices`, on the customer's tap.
  Future<void> refresh() async {
    if (state.fetchState == LiveFetchState.loading) return;
    final country = ref.read(settingsRepositoryProvider).cached()?.country;
    final location = marketFor(country)?.nameAr ?? 'السعودية';
    state = LiveMarketView(
      prices: state.prices,
      fetchState: LiveFetchState.loading,
    );
    try {
      final client = ref.read(supabaseClientProvider);
      // A hard ceiling above the HTTP timeout, as in Kotlin: any hang
      // underneath must end in a final state, never loading forever.
      final response = await client.functions
          .invoke(
            'zad-core-intelligence',
            body: <String, dynamic>{
              'action': 'fetch_live_market_prices',
              'user_id': client.auth.currentUser?.id,
              'payload': <String, dynamic>{'location': location},
            },
          )
          .timeout(const Duration(seconds: 120));
      final data = response.data;
      if (data is Map && data['ok'] == false) {
        throw StateError('fetch_live_market_prices: upstream search failed');
      }
      final raw = data is Map ? data['prices'] : null;
      final fetched = raw is List
          ? raw.map(MarketPriceItem.tryParse).nonNulls.toList()
          : const <MarketPriceItem>[];
      if (!ref.mounted) return;
      if (fetched.isNotEmpty) {
        unawaited(
          ref
              .read(localStoreProvider)
              .device
              .put(
                _cacheKey(country),
                jsonEncode(<Map<String, dynamic>>[
                  for (final p in fetched) p.toJson(),
                ]),
              ),
        );
      }
      state = LiveMarketView(
        prices: fetched.isNotEmpty ? fetched : state.prices,
        fetchState: LiveFetchState.fetched,
      );
    } on Object catch (e) {
      debugPrint('refreshLiveMarketPrices() FAILED: $e');
      if (!ref.mounted) return;
      state = LiveMarketView(
        prices: state.prices,
        fetchState: LiveFetchState.error,
      );
    }
  }
}

/// The strip's state.
final liveMarketControllerProvider =
    NotifierProvider<LiveMarketController, LiveMarketView>(
      LiveMarketController.new,
    );
