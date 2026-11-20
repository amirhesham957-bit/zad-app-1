/// «عروضي»'s state: the last answer from the phone at once, then the server's.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/features/offers/data/offers_repository.dart';
import 'package:zad/features/offers/domain/offers.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';

/// What the screen draws.
class OffersState {
  /// Creates a state.
  const new({
    this.partner = const <Offer>[],
    this.mine = const <Offer>[],
    this.loading = true,
  });

  /// Partner offers for the account's country.
  final List<Offer> partner;

  /// Offers from the customer's own notifications.
  final List<Offer> mine;

  /// No answer yet, cached or live.
  final bool loading;
}

/// Loads the offers once per open, and again on pull-to-refresh. No model call.
class OffersController extends Notifier<OffersState> {
  @override
  OffersState build() {
    final repo = ref.read(offersRepositoryProvider);
    final country = ref.read(accountCountryProvider);
    final kept = repo.cached();
    unawaited(Future<void>.microtask(refresh));
    return kept == null ? const OffersState() : _from(kept, country);
  }

  OffersState _from(OfferRows rows, String? country) => OffersState(
    partner: partnerOffersFrom(rows.coupons, country: country),
    mine: notificationOffersFrom(rows.mine),
    loading: false,
  );

  /// Re-reads the server; keeps what is shown when it cannot be reached.
  Future<void> refresh() async {
    final country = ref.read(accountCountryProvider);
    final rows = await ref
        .read(offersRepositoryProvider)
        .fetch(country: country);
    if (!ref.mounted) return;
    state = rows == null
        ? OffersState(partner: state.partner, mine: state.mine, loading: false)
        : _from(rows, country);
  }
}

/// The controller's provider.
final offersControllerProvider =
    NotifierProvider<OffersController, OffersState>(OffersController.new);
