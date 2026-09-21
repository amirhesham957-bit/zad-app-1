/// Whether the signed-in account has told us which market it is in.
///
/// An account with no country is not a cosmetic gap. The server puts it on
/// UTC (`zad_market_timezone`), so a Cairo customer's eight o'clock tablet is
/// due at ten, and their salary cycle turns over two hours late. Two of the
/// four live accounts were in that state on 2026-09-21. This is what stops the
/// app opening onto a budget computed on the wrong clock.
///
/// The rule it follows is the Kotlin app's hard-won one, from the other side:
/// an empty device is **not** evidence the customer never chose. Kotlin asked
/// again after every reinstall until it learnt to ask the server first, and
/// its customers reported choosing twice (2026-09-14). So this asks the server
/// whenever the device does not know, and only shows the picker when the
/// server's answer, or the device's own last copy of it, says there is none.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/auth/application/session_controller.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/market/domain/market.dart';
import 'package:zad/features/settings/data/settings_repository.dart';
import 'package:zad/features/settings/domain/account_settings.dart';

/// What the gate knows about the account's market.
enum MarketGate {
  /// The account has one. Open the app.
  chosen,

  /// It has none — the server said so, or the device's copy of the server's
  /// row does. Ask.
  missing,

  /// The device has never read the account's settings, and the server is
  /// being asked. Brief, and bounded by [MarketGateController.checkTimeout].
  checking,

  /// The server could not be asked and the device does not know. Open the app
  /// anyway: asking a customer to choose again when they may already have is
  /// the bug this gate was built to avoid, and an app that will not open
  /// without a network is worse than a zone that is wrong until it has one.
  /// The check runs again on the next sign-in or launch.
  unknown,
}

/// Decides [MarketGate] and records the customer's choice.
class MarketGateController extends Notifier<MarketGate> {
  /// How long the first check may hold the app closed.
  ///
  /// Long enough for a slow mobile network to answer one small `select`, short
  /// enough that a dead connection does not look like a frozen app.
  static const Duration checkTimeout = Duration(seconds: 8);

  /// What the customer picked on this device, for [_check] to hold to.
  Market? _picked;

  @override
  MarketGate build() {
    // Rebuilt on every account change, which is what makes a second account
    // on the same phone get its own check rather than inheriting the first
    // one's answer.
    final userId = ref.watch(sessionControllerProvider);
    if (userId == null) return MarketGate.unknown;

    final cached = ref.read(settingsRepositoryProvider).cached();
    if (_hasMarket(cached)) return MarketGate.chosen;

    // A microtask, so nothing in the check can touch `state` before `build`
    // has returned it.
    unawaited(Future<void>.microtask(() => ref.mounted ? _check() : null));

    // A cached row with no country is the server's own earlier answer, so the
    // picker can open at once; the check still runs, in case the country was
    // set from somewhere else since (the Kotlin app, the Telegram bot).
    return cached == null ? MarketGate.checking : MarketGate.missing;
  }

  Future<void> _check() async {
    try {
      final settings = await ref
          .read(settingsRepositoryProvider)
          .refresh()
          .timeout(checkTimeout);
      if (!ref.mounted) return;
      // The zone was computed from whatever the cache held before this read,
      // and it is a plain provider: it keeps that answer until told otherwise.
      ref.invalidate(accountTimeZoneProvider);
      if (state == MarketGate.chosen) {
        // The customer picked while this read was in flight, so its answer is
        // older than the pick. If the pick was already sent and dequeued by
        // the time the read came back, there was nothing queued to lay over
        // the server's old null, and the refresh has just cached it — the
        // zone would drop back to UTC, and the next launch would open on the
        // picker. Saying the pick again is an idempotent upsert, and it only
        // happens in exactly that case.
        final picked = _picked;
        if (picked != null && settings.country != picked.country) {
          await _save(picked);
        }
        return;
      }
      state = _hasMarket(settings) ? MarketGate.chosen : MarketGate.missing;
    } on Object {
      if (!ref.mounted) return;
      // Only "don't know" becomes "open anyway". A device that already holds
      // the server's "none" keeps the picker up: the network failing is no
      // reason to believe the answer changed.
      if (state == MarketGate.checking) state = MarketGate.unknown;
    }
  }

  /// Records [market] as the account's, and opens the app.
  ///
  /// Saved on the device and queued before the app opens, then sent. The app
  /// does not wait for the send: the choice is already the account's on this
  /// phone, and the outbox carries it up when there is a network.
  Future<void> choose(Market market) async {
    _picked = market;
    await _save(market);
    if (ref.mounted) state = MarketGate.chosen;
  }

  Future<void> _save(Market market) async {
    await ref
        .read(settingsRepositoryProvider)
        .setMarket(country: market.country, currency: market.currency);
    if (!ref.mounted) return;
    ref.invalidate(accountTimeZoneProvider);
    unawaited(_deliver());
  }

  /// Sends the choice, then asks for a budget computed in the new zone.
  Future<void> _deliver() async {
    final outbox = ref.read(outboxProvider);
    try {
      await outbox.flush();
    } on Object {
      // The entry stays queued and the runner's next trigger sends it.
      return;
    }
    if (!ref.mounted) return;
    // Asked of this entry, not of the queue: the queue is sent strictly in
    // order and may be held up by something unrelated, and an unrelated
    // leftover is no reason to skip the refresh once this one is through.
    final stillQueued = outbox
        .entries(includeDead: false)
        .any((e) => e.id == SettingsRepository.outboxIdFor('market'));
    if (stillQueued) return;
    // The budget the home screen is about to show was computed before the
    // server knew the country — on UTC, and without a currency. Forced past
    // the cooldown for that reason, and only once the country has landed:
    // asking before it has would fetch the same wrong answer again.
    unawaited(ref.read(budgetControllerProvider.notifier).refresh(force: true));
  }

  static bool _hasMarket(AccountSettings? settings) =>
      isKnownMarket(settings?.country);
}

/// The market gate.
final marketGateProvider = NotifierProvider<MarketGateController, MarketGate>(
  MarketGateController.new,
);
