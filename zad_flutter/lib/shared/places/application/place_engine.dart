/// What a stored place event means, and what to do about it.
///
/// One class for both engines: the app's (on an `events` cue, and on open)
/// and the headless one `placeBackgroundMain` starts when the app is closed.
/// Neither has the other's memory, so everything it remembers is in the
/// native [PlaceHost] state blob, read at the start of a run and written at
/// the end.
///
/// A run that dies half way (the headless watchdog, no network) leaves its
/// events unacknowledged and runs them again. That is safe because the
/// server is the one that dedupes: `store_arrival` allows one message per
/// shop a day, and `place_event` upserts on the time of leaving.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/alerts/data/push_platform.dart';
import 'package:zad/shared/alerts/domain/push_alert.dart';
import 'package:zad/shared/nearby/data/nearby_remote.dart';
import 'package:zad/shared/nearby/domain/nearby.dart';
import 'package:zad/shared/places/data/place_server.dart';
import 'package:zad/shared/places/domain/places.dart';
import 'package:zad_geofence/zad_geofence.dart';

/// The native side: `ZadGeofence`, behind an interface for tests.
abstract interface class PlaceHost {
  /// Stored events.
  Future<List<PlaceEvent>> peek();

  /// Drops handled events.
  Future<void> acknowledge(Iterable<int> keys);

  /// Replaces every fence. Throws when Android refuses.
  Future<void> register(List<Fence> fences);

  /// Removes every fence.
  Future<void> clear();

  /// The state blob.
  Future<String?> readState();

  /// Replaces the state blob.
  Future<void> writeState(String state);

  /// Starts the nightly sample.
  Future<void> scheduleNight(DateTime at);

  /// Stops it.
  Future<void> cancelNight();
}

/// [PlaceHost] over the plugin.
class PluginPlaceHost implements PlaceHost {
  /// Creates the host.
  const new([this._plugin = const ZadGeofence()]);

  final ZadGeofence _plugin;

  @override
  Future<List<PlaceEvent>> peek() => _plugin.peek();

  @override
  Future<void> acknowledge(Iterable<int> keys) => _plugin.acknowledge(keys);

  @override
  Future<void> register(List<Fence> fences) => _plugin.register(fences);

  @override
  Future<void> clear() => _plugin.clear();

  @override
  Future<String?> readState() => _plugin.readState();

  @override
  Future<void> writeState(String state) => _plugin.writeState(state);

  @override
  Future<void> scheduleNight(DateTime at) => _plugin.scheduleNight(at);

  @override
  Future<void> cancelNight() => _plugin.cancelNight();
}

/// What the server does with a place.
abstract interface class PlaceServer {
  /// `store_arrival`: the alert to show, or null when the server has nothing
  /// to say (nothing missing, muted, already told today). Throws when it
  /// cannot be reached.
  Future<PushAlert?> storeArrival({
    required String name,
    required StoreKind kind,
  });

  /// `place_event` back_home. Throws when it cannot be reached.
  Future<void> backHome(DateTime leftAt);

  /// `zad_users.last_*`, so the chat's "what is near me" has a point. Coarse.
  Future<void> saveLastLocation(GeoPoint coarse);

  /// `zad_family_zone_event`: this phone entered or left a child zone. The
  /// server decides whether a parent hears of it. A refusal (sharing
  /// stopped, zone gone) is an answer, not an error; throws only when the
  /// server cannot be reached.
  Future<void> zoneEvent({
    required String zoneId,
    required PlaceTransition transition,
    required DateTime at,
  });
}

/// Shops of [kind] around [at] (already coarse).
typedef ShopFinder = Future<List<NearbyStore>> Function(
  GeoPoint at,
  StoreKind kind,
);

/// The engine.
class PlaceEngine {
  /// Creates the engine.
  const new({
    required PlaceHost host,
    required PlaceServer server,
    required ShopFinder findShops,
    required Future<void> Function(PushAlert alert) notify,
    required DateTime Function() now,
  }) : _host = host,
       _server = server,
       _findShops = findShops,
       _notify = notify,
       _now = now;

  final PlaceHost _host;
  final PlaceServer _server;
  final ShopFinder _findShops;
  final Future<void> Function(PushAlert alert) _notify;
  final DateTime Function() _now;

  /// The stored state; the default when there is none or it is unreadable.
  Future<PlaceState> state() async {
    final raw = await _host.readState();
    if (raw == null) return const PlaceState();
    try {
      final json = jsonDecode(raw);
      return json is Map<String, dynamic>
          ? PlaceState.fromJson(json)
          : const PlaceState();
    } on FormatException {
      return const PlaceState();
    }
  }

  Future<void> _save(PlaceState state) =>
      _host.writeState(jsonEncode(state.toJson()));

  /// Street alerts on, from [at] in the account's [zone]. Throws when
  /// Android will not register the fences (no "all the time" permission).
  Future<void> enable({required GeoPoint at, required String zone}) async {
    final state = (await this.state()).copyWith(enabled: true, zone: zone);
    await _save(state);
    await refresh(at, state: state);
    await _host.scheduleNight(nextNightSample(_now(), tz.getLocation(zone)));
  }

  /// Street alerts off. Home and the nights are kept: turning it back on
  /// should not mean two more nights of learning. A child's zones stay
  /// watched — they are a separate yes.
  Future<void> disable() async {
    await _host.cancelNight();
    final state = (await this.state()).copyWith(
      enabled: false,
      shops: const <String, FencedShop>{},
      shopFences: const <Fence>[],
    );
    await _save(state);
    await _registerAll(state);
  }

  /// Every fence this phone should watch: the street ones while street
  /// alerts are on, and the child zones always. `register` replaces them
  /// all, so they always go together.
  Future<void> _registerAll(PlaceState state) async {
    final fences = <Fence>[
      if (state.enabled) ...state.shopFences,
      ...zoneFences(state.zones.values),
    ];
    if (fences.isEmpty) {
      await _host.clear();
    } else {
      await _host.register(fences);
    }
  }

  /// The child zones from the server (`zad_family_my_zones`). Registers only
  /// when they changed: Android reports «entered» straight away for a fence
  /// the phone is already inside, so registering the same zones on every
  /// sync would report the school again each time. Throws when Android
  /// refuses the fences (no "all the time" permission).
  Future<void> setZones(List<ChildZone> zones) async {
    var state = await this.state();
    final next = <String, ChildZone>{
      for (final z in zones) zoneFenceId(z.id): z,
    };
    if (mapEquals(next, state.zones)) return;
    state = state.copyWith(zones: next);
    // A blob from before the street fences were kept: look the shops up
    // again rather than drop them by registering the zones alone.
    final center = state.center;
    if (state.enabled && state.shopFences.isEmpty && center != null) {
      try {
        await refresh(center, state: state);
        return;
      } on Object catch (e) {
        debugPrint('[places] refresh for zones failed: $e');
      }
    }
    // Saved only once Android took them: a refusal leaves the old zones
    // stored, so the next sync tries again instead of thinking it is done.
    await _registerAll(state);
    await _save(state);
  }

  /// Looks the shops up again round [at] and registers them, home and the
  /// area. Throws when registering does.
  Future<PlaceState> refresh(GeoPoint at, {PlaceState? state}) async {
    var current = state ?? await this.state();
    final shops = <NearbyStore>[];
    for (final kind in StoreKind.values) {
      try {
        shops.addAll(await _findShops(at.coarse, kind));
      } on Object catch (e) {
        // One kind failing still leaves the other, home and the area.
        debugPrint('[places] no ${kind.tag} shops: $e');
      }
    }
    final plan = planFences(shops: shops, center: at, home: current.home);
    current = current.copyWith(
      shops: plan.shops,
      shopFences: plan.fences,
      refreshedAt: _now(),
      center: at,
    );
    await _registerAll(current);
    await _save(current);
    try {
      await _server.saveLastLocation(at.coarse);
    } on Object catch (e) {
      debugPrint('[places] last location not saved: $e');
    }
    return current;
  }

  /// Deals with every stored event, oldest first.
  Future<void> handlePending() async {
    var state = await this.state();
    final all = [...await _host.peek()]..sort((a, b) => a.at.compareTo(b.at));
    if (all.isEmpty) return;
    // Child zones first, street alerts on or off: each goes to the server,
    // which decides whether a parent hears of it. One that cannot be sent
    // waits, with the ones after it, for the next run.
    final zoneDone = <int>[];
    for (final e in all.where((e) => zoneIdOfFence(e.fence) != null)) {
      if (e.transition != PlaceTransition.night) {
        try {
          await _server.zoneEvent(
            zoneId: zoneIdOfFence(e.fence)!,
            transition: e.transition,
            at: e.at,
          );
        } on Object catch (err) {
          debugPrint('[places] zone event not sent: $err');
          break;
        }
      }
      zoneDone.add(e.key);
    }
    if (zoneDone.isNotEmpty) await _host.acknowledge(zoneDone);
    final events = <PlaceEvent>[
      for (final e in all)
        if (zoneIdOfFence(e.fence) == null) e,
    ];
    if (events.isEmpty) return;
    if (!state.enabled) {
      await _host.acknowledge(events.map((e) => e.key));
      return;
    }
    final zone = tz.getLocation(state.zone);
    final now = _now();
    final done = <int>[];
    final entered = <FencedShop>[];
    GeoPoint? lookFrom;
    GeoPoint? lastSeen;

    for (final e in events) {
      final at = e.lat != null && e.lon != null
          ? GeoPoint(e.lat!, e.lon!)
          : null;
      if (at != null) lastSeen = at;

      if (e.fence == ZadGeofence.nightFence) {
        final local = tz.TZDateTime.from(e.at, zone);
        if (at != null && isNightHour(local)) {
          final recorded = recordNight(
            state,
            at,
            DateFormat('yyyy-MM-dd').format(local),
          );
          state = recorded.state;
          if (recorded.homeChanged) lookFrom ??= state.center ?? at;
        }
      } else if (e.fence == kHomeFence) {
        if (e.transition == PlaceTransition.exit) {
          state = state.copyWith(leftAt: state.leftAt ?? e.at);
        } else {
          final leftAt = state.leftAt;
          if (leftAt != null && isOuting(leftAt, e.at)) {
            try {
              await _server.backHome(leftAt);
            } on Object catch (err) {
              // Kept, with leftAt, for the next run; later events wait too,
              // or a second outing could be read against the wrong leaving.
              debugPrint('[places] back_home not sent: $err');
              break;
            }
          }
          state = state.copyWith(clearLeftAt: true);
        }
      } else if (e.fence == kAreaFence) {
        if (e.transition == PlaceTransition.exit && at != null) lookFrom = at;
      } else {
        final shop = state.shops[e.fence];
        if (shop != null &&
            e.transition == PlaceTransition.enter &&
            now.difference(e.at) <= kStaleArrival &&
            !isStillHome(state) &&
            !isRegistrationEcho(state, e.at)) {
          entered.add(shop);
        }
      }
      done.add(e.key);
    }

    // One alert per run: two shops side by side are one stop, not two.
    final shop = entered
        .where((s) => !_alertedRecently(state, s.name, now))
        .firstOrNull;
    if (shop != null) {
      try {
        final alert = await _server.storeArrival(
          name: shop.name,
          kind: shop.kind,
        );
        state = state.copyWith(
          alerted: <String, DateTime>{
            for (final MapEntry(:key, :value) in state.alerted.entries)
              if (now.difference(value) < kShopCooldown) key: value,
            shop.name.toLowerCase(): now,
          },
        );
        if (alert != null && alert.isShowable) await _notify(alert);
      } on Object catch (err) {
        debugPrint('[places] store_arrival failed: $err');
      }
    }

    await _save(state);
    await _host.acknowledge(done);

    final stale =
        state.refreshedAt == null ||
        now.difference(state.refreshedAt!) >= kRefreshEvery;
    final from = lookFrom ?? (stale ? lastSeen : null);
    if (from != null) {
      try {
        await refresh(from, state: state);
      } on Object catch (err) {
        debugPrint('[places] refresh failed: $err');
      }
    }
  }

  static bool _alertedRecently(PlaceState s, String name, DateTime now) {
    final at = s.alerted[name.toLowerCase()];
    return at != null && now.difference(at) < kShopCooldown;
  }
}

/// The geofence plugin. Null — street alerts unavailable — unless
/// `bootstrap()` installed the real one, so no test reaches a plugin.
final placeHostProvider = Provider<PlaceHost?>((ref) => null);

/// Street alerts' engine in the app's own engine; null without a host.
final Provider<PlaceEngine?> placeEngineProvider = Provider<PlaceEngine?>((
  ref,
) {
  final host = ref.watch(placeHostProvider);
  if (host == null) return null;
  final client = http.Client();
  ref.onDispose(client.close);
  final supabase = ref.watch(supabaseClientProvider);
  final remote = ServerThenOverpassRemote(supabaseServerCall(supabase), client);
  final push = ref.watch(pushPlatformProvider);
  return PlaceEngine(
    host: host,
    server: SupabasePlaceServer(supabase),
    findShops: (at, kind) =>
        remote.stores(at: at, kind: kind, radius: kSearchRadius),
    notify: push.show,
    now: ref.watch(nowProvider),
  );
});

/// Home is known and the phone has not left its circle since: a shop "enter"
/// now is the shop down the street seen through the walls (a 120 m circle,
/// indoor GPS), not a trip to it. Unknown home = cannot tell, so not home.
@visibleForTesting
bool isStillHome(PlaceState state) =>
    state.home != null && state.leftAt == null;

/// An enter reported within [kRegistrationEcho] of the shops being
/// registered — Android's initial trigger for a circle the phone was already
/// in.
@visibleForTesting
bool isRegistrationEcho(PlaceState state, DateTime at) {
  final registered = state.refreshedAt;
  if (registered == null || at.isBefore(registered)) return false;
  return at.difference(registered) < kRegistrationEcho;
}
