/// The real prices the companion's price games ask about (ZAD_PLAN ٥.٤).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/shared/companion/domain/price_games.dart';
import 'package:zad/shared/market/domain/market.dart';
import 'package:zad/shared/prices/data/prices_repository.dart';
import 'package:zad/shared/prices/domain/prices.dart';
import 'package:zad/shared/settings/data/settings_repository.dart';
import 'package:zad/shared/transactions/application/transactions_controller.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

/// The account's currency symbol, or empty before a market is chosen.
final priceGameCurrencyProvider = Provider<String>((ref) {
  try {
    return marketFor(ref.read(settingsRepositoryProvider).cached()?.country)
            ?.currencySymbol ??
        '';
  } on Object {
    return '';
  }
});

/// The city's prices as last fetched — fetched once when the phone has none
/// yet, on the customer's tap — and the period's own expenses.
final FutureProvider<List<PriceFact>> petPriceFactsProvider =
    FutureProvider.autoDispose<List<PriceFact>>((ref) async {
      var crowd = const <CheapestPrice>[];
      try {
        final repository = ref.read(pricesRepositoryProvider);
        var snapshot = repository.cachedCheapest();
        final currency = marketFor(
          ref.read(settingsRepositoryProvider).cached()?.country,
        )?.currency;
        if (snapshot == null && currency != null) {
          snapshot = await repository.refreshCheapest(
            currency: currency,
            city: repository.lastCity(),
          );
        }
        crowd = snapshot?.rows ?? crowd;
      } on Object catch (e) {
        debugPrint('[price_games] city prices unavailable: $e');
      }
      var spent = const <ZadTransaction>[];
      try {
        spent = ref.read(transactionsControllerProvider).rows;
      } on Object catch (e) {
        debugPrint('[price_games] expenses unavailable: $e');
      }
      return priceFactsFrom(crowd: crowd, spent: spent);
    });
