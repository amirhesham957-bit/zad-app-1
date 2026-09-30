/// Street alerts in the app's own engine: the settings switch, and the
/// runner that handles place events while the app is open.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/features/places/data/background_location.dart';
import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/nearby/data/location_source.dart';
import 'package:zad/shared/places/application/place_engine.dart';
import 'package:zad/shared/places/domain/places.dart';
import 'package:zad_geofence/zad_geofence.dart';

/// Where the switch stands.
enum StreetAlertsStatus {
  /// Not read yet.
  unknown,

  /// No geofence plugin (tests).
  unavailable,

  /// Off.
  off,

  /// On and registered.
  on,

  /// On, but "Allow all the time" is missing — nothing fires.
  needsAlways,

  /// Location is off on the phone, or refused outright.
  needsLocation,

  /// No position came in time.
  noFix,

  /// Android refused the fences for another reason.
  failed,
}

/// What the settings row shows.
@immutable
class StreetAlertsView {
  /// Creates a view.
  const new({
    this.status = StreetAlertsStatus.unknown,
    this.busy = false,
    this.homeLearned = false,
  });

  /// Where it stands.
  final StreetAlertsStatus status;

  /// Turning on or off.
  final bool busy;

  /// Whether home is known yet (two nights).
  final bool homeLearned;
}

/// The switch.
class StreetAlertsController extends Notifier<StreetAlertsView> {
  @override
  StreetAlertsView build() {
    unawaited(Future<void>.microtask(() => ref.mounted ? reload() : null));
    return const StreetAlertsView();
  }

  /// Reads where things stand — on open, and back from system settings.
  Future<void> reload() async {
    final engine = ref.read(placeEngineProvider);
    if (engine == null) {
      state = const StreetAlertsView(status: StreetAlertsStatus.unavailable);
      return;
    }
    final saved = await engine.state();
    final always = await ref.read(backgroundLocationProvider).granted();
    if (!ref.mounted) return;
    state = StreetAlertsView(
      status: !saved.enabled
          ? StreetAlertsStatus.off
          : always
          ? StreetAlertsStatus.on
          : StreetAlertsStatus.needsAlways,
      homeLearned: saved.home != null,
    );
  }

  /// On, after the customer read why. Asks for location, then "all the
  /// time", then takes one fix and registers round it.
  Future<void> turnOn() async {
    final engine = ref.read(placeEngineProvider);
    if (engine == null || state.busy) return;
    state = StreetAlertsView(busy: true, homeLearned: state.homeLearned);
    final source = ref.read(locationSourceProvider);
    final always = ref.read(backgroundLocationProvider);

    var access = await source.access();
    if (access == LocationAccess.denied) access = await source.request();
    if (access != LocationAccess.granted) {
      return _settle(StreetAlertsStatus.needsLocation);
    }
    if (!await always.granted() && !await always.request()) {
      return _settle(StreetAlertsStatus.needsAlways);
    }
    final fix = await source.current() ?? await source.lastKnown();
    if (fix == null) return _settle(StreetAlertsStatus.noFix);
    try {
      await engine.enable(at: fix.at, zone: ref.read(accountTimeZoneProvider));
    } on Object catch (e) {
      debugPrint('[places] enable failed: $e');
      return _settle(StreetAlertsStatus.failed);
    }
    await reload();
  }

  /// Off.
  Future<void> turnOff() async {
    final engine = ref.read(placeEngineProvider);
    if (engine == null || state.busy) return;
    state = StreetAlertsView(busy: true, homeLearned: state.homeLearned);
    try {
      await engine.disable();
    } on Object catch (e) {
      debugPrint('[places] disable failed: $e');
    }
    await reload();
  }

  /// The screen that fixes [StreetAlertsStatus.needsAlways] or
  /// [StreetAlertsStatus.needsLocation].
  Future<void> openSettings() async {
    if (state.status == StreetAlertsStatus.needsLocation &&
        await ref.read(locationSourceProvider).access() ==
            LocationAccess.serviceOff) {
      await ref.read(locationSourceProvider).openLocationSettings();
      return;
    }
    await ref.read(backgroundLocationProvider).openSettings();
  }

  void _settle(StreetAlertsStatus status) {
    if (ref.mounted) {
      state = StreetAlertsView(status: status, homeLearned: state.homeLearned);
    }
  }
}

/// The switch.
final streetAlertsControllerProvider =
    NotifierProvider<StreetAlertsController, StreetAlertsView>(
      StreetAlertsController.new,
    );

/// Handles place events in the app's engine: those stored while it was
/// closed, on start, and each new one as it arrives. On start it also looks
/// the shops up again if the last look is older than [kRefreshEvery] — from
/// the phone's last position, which wakes no radio.
///
/// Watched by `ZadApp` for as long as the app lives; does nothing without a
/// geofence plugin or a signed-in account.
final Provider<void> placesRunnerProvider = Provider<void>((ref) {
  final engine = ref.watch(placeEngineProvider);
  if (engine == null || ref.watch(sessionControllerProvider) == null) return;
  final source = ref.read(locationSourceProvider);
  final now = ref.read(nowProvider);

  var queue = Future<void>.value();
  void run(Future<void> Function() job) {
    queue = queue.then((_) => job()).catchError((Object e) {
      debugPrint('[places] runner: $e');
    });
  }

  final arrivals = const ZadGeofence().arrivals.listen(
    (_) => run(engine.handlePending),
  );
  ref.onDispose(arrivals.cancel);

  run(engine.handlePending);
  run(() async {
    final saved = await engine.state();
    final last = saved.refreshedAt;
    if (!saved.enabled ||
        (last != null && now().difference(last) < kRefreshEvery)) {
      return;
    }
    final fix = await source.lastKnown();
    if (fix != null) await engine.refresh(fix.at);
  });
});
