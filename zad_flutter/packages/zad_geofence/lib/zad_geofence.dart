/// Android geofences and a nightly location sample, durably.
///
/// Transitions arrive whether or not the app is open — the normal case for
/// someone walking past a shop — so the native side writes each one to a
/// small store first and only then wakes Dart: the app's engine if there is
/// one, otherwise a headless engine running the function registered with
/// [ZadGeofence.registerBackgroundHandle].
///
/// Like `zad_bank_listener`, this package holds no judgement. What an event
/// means (a shop, home, time to look for new shops) is decided in the app.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A circle Android watches.
@immutable
class Fence {
  /// Creates a fence.
  const new({
    required this.id,
    required this.lat,
    required this.lon,
    required this.radius,
    this.enter = true,
    this.exit = false,
  });

  /// Comes back in every event it triggers.
  final String id;

  /// Centre latitude.
  final double lat;

  /// Centre longitude.
  final double lon;

  /// Metres. Android does not promise much below ~100.
  final double radius;

  /// Report entering it.
  final bool enter;

  /// Report leaving it.
  final bool exit;

  /// For the channel.
  Map<String, Object> toJson() => <String, Object>{
    'id': id,
    'lat': lat,
    'lon': lon,
    'radius': radius,
    'enter': enter,
    'exit': exit,
  };
}

/// What happened.
enum PlaceTransition {
  /// The phone came into a fence.
  enter,

  /// It left one.
  exit,

  /// The nightly sample: where the phone is while its owner sleeps.
  night,
}

/// One event from the store.
@immutable
class PlaceEvent {
  /// Creates an event.
  const new({
    required this.key,
    required this.fence,
    required this.transition,
    required this.at,
    this.lat,
    this.lon,
  });

  /// Reads a row from the channel.
  static PlaceEvent? fromMap(Map<Object?, Object?> map) {
    final transition = switch (map['transition']) {
      'enter' => PlaceTransition.enter,
      'exit' => PlaceTransition.exit,
      'night' => PlaceTransition.night,
      _ => null,
    };
    if (transition == null) return null;
    return PlaceEvent(
      key: (map['key']! as num).toInt(),
      fence: map['fence']! as String,
      transition: transition,
      at: DateTime.fromMillisecondsSinceEpoch(
        (map['at']! as num).toInt(),
        isUtc: true,
      ),
      lat: (map['lat'] as num?)?.toDouble(),
      lon: (map['lon'] as num?)?.toDouble(),
    );
  }

  /// The store's id for it, to acknowledge.
  final int key;

  /// Which fence — `zad_night` for the nightly sample.
  final String fence;

  /// Enter, exit or night.
  final PlaceTransition transition;

  /// When the phone saw it.
  final DateTime at;

  /// Where the phone was, when Android said.
  final double? lat;

  /// Where the phone was, when Android said.
  final double? lon;
}

/// The plugin.
class ZadGeofence {
  /// Creates the plugin over the default channel.
  const new();

  /// For tests.
  @visibleForTesting
  static const MethodChannel channel = MethodChannel(
    'com.aistudio.zad/geofence',
  );

  /// The fence id of the nightly sample.
  static const String nightFence = 'zad_night';

  /// Location granted "all the time" — what fences need to fire with the app
  /// closed.
  Future<bool> hasBackgroundPermission() async =>
      await channel.invokeMethod<bool>('hasBackgroundPermission') ?? false;

  /// Replaces every fence with [fences]. Kept natively too, so a reboot
  /// re-registers them without the app. Throws a [PlatformException] when
  /// Android refuses (no permission, location off).
  Future<void> register(List<Fence> fences) =>
      channel.invokeMethod<void>('register', <String, Object>{
        'fences': jsonEncode(<Object>[for (final f in fences) f.toJson()]),
      });

  /// Removes every fence.
  Future<void> clear() => channel.invokeMethod<void>('clear');

  /// The nightly sample fires first at [at] and then every 24 hours.
  Future<void> scheduleNight(DateTime at) => channel.invokeMethod<void>(
    'scheduleNight',
    <String, Object>{'at': at.millisecondsSinceEpoch},
  );

  /// Stops the nightly sample.
  Future<void> cancelNight() => channel.invokeMethod<void>('cancelNight');

  /// Every stored event, oldest first, without consuming them.
  Future<List<PlaceEvent>> peek() async {
    final rows = await channel.invokeListMethod<Object?>('peek');
    return <PlaceEvent>[
      for (final row in rows ?? const <Object?>[])
        if (row is Map<Object?, Object?>) ?PlaceEvent.fromMap(row),
    ];
  }

  /// Drops the events the app has dealt with.
  Future<void> acknowledge(Iterable<int> keys) => channel.invokeMethod<void>(
    'acknowledge',
    <String, Object>{'keys': keys.toList()},
  );

  /// The app's own state, kept natively so the app's engine and the
  /// headless one read the same thing. Null before the first write.
  Future<String?> readState() => channel.invokeMethod<String>('readState');

  /// Replaces the state.
  Future<void> writeState(String state) => channel.invokeMethod<void>(
    'writeState',
    <String, Object>{'state': state},
  );

  /// Which Dart function runs an event when the app is not open: a top-level
  /// function marked `@pragma('vm:entry-point')`. Registered on every start,
  /// since an update can move it.
  Future<void> registerBackgroundHandle(int handle) =>
      channel.invokeMethod<void>('registerBackgroundHandle', <String, Object>{
        'handle': handle,
      });

  /// The background function is finished; its engine may stop.
  Future<void> backgroundDone() => channel.invokeMethod<void>('backgroundDone');

  /// Fires when an event is stored while the app is open.
  Stream<void> get arrivals => _arrivals.stream;

  static final StreamController<void> _arrivals =
      StreamController<void>.broadcast(onListen: _listen);

  static void _listen() {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'events') _arrivals.add(null);
    });
  }
}
