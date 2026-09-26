/// Captured Android notifications, durably.
///
/// The listener service runs whether or not the app is open — which is the
/// normal case for a bank message, not the exception — so what it captures
/// goes to SQLite on the device rather than to a Flutter engine that may not
/// exist. This package is the door to that inbox.
///
/// It deliberately holds no judgement about what is or is not a bank message.
/// That decision is in the app, in `bank_notification.dart`, pinned by parity
/// tests against the Kotlin it came from.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One notification the service saw.
class CapturedNotification {
  /// Creates a captured notification.
  const new({
    required this.id,
    required this.packageName,
    required this.title,
    required this.text,
    required this.postedAt,
  });

  /// Reads a row from the platform channel.
  factory fromMap(Map<Object?, Object?> map) => CapturedNotification(
    id: (map['id']! as num).toInt(),
    packageName: map['package_name']! as String,
    title: map['title']! as String,
    text: map['text']! as String,
    postedAt: DateTime.fromMillisecondsSinceEpoch(
      (map['posted_at']! as num).toInt(),
      isUtc: true,
    ),
  );

  /// The inbox row id, used to acknowledge it.
  final int id;

  /// Which app posted it. Note the bank channel's package is the messaging
  /// app, and it is not in any tracked list.
  final String packageName;

  /// The notification's title.
  final String title;

  /// Its body.
  final String text;

  /// When the system posted it.
  final DateTime postedAt;
}

/// The plugin.
class ZadBankListener {
  /// Creates a listener over the default channel.
  const new();

  /// For tests.
  @visibleForTesting
  static const MethodChannel channel = MethodChannel(
    'com.aistudio.zad/bank_listener',
  );

  /// Whether the user has granted notification access.
  ///
  /// Granted is not the same as running — see [requestRebind].
  Future<bool> isPermissionGranted() async =>
      await channel.invokeMethod<bool>('isPermissionGranted') ?? false;

  /// Opens the system screen where the user grants it. There is no in-app
  /// prompt for this permission; it cannot be requested from code.
  Future<void> openPermissionSettings() =>
      channel.invokeMethod<void>('openPermissionSettings');

  /// Asks Android to bind the service again.
  ///
  /// Worth calling on every app open. Android kills notification listeners
  /// under memory pressure or after an update and sometimes never rebinds them
  /// on its own — which looks exactly like "the permission is off", except the
  /// permission is on and nothing is arriving. Returns false when there was
  /// nothing to do because access was never granted.
  Future<bool> requestRebind() async =>
      await channel.invokeMethod<bool>('requestRebind') ?? false;

  /// The oldest captured notifications, without consuming them.
  Future<List<CapturedNotification>> peek({int limit = 100}) async {
    final rows = await channel.invokeListMethod<Object?>(
      'peek',
      <String, Object>{'limit': limit},
    );
    return (rows ?? const <Object?>[])
        .cast<Map<Object?, Object?>>()
        .map(CapturedNotification.fromMap)
        .toList();
  }

  /// Drops the rows the app has taken responsibility for.
  ///
  /// Separate from [peek] on purpose: deleting on read means an app that dies
  /// between the two swallows the notification. Delivering twice is recoverable
  /// — the outbox collides on the row id — and losing a bank message is not.
  Future<void> acknowledge(Iterable<int> ids) => channel.invokeMethod<void>(
    'acknowledge',
    <String, Object>{'ids': ids.toList()},
  );

  /// How many are waiting. Cheap enough for a status row.
  Future<int> pendingCount() async =>
      await channel.invokeMethod<int>('pendingCount') ?? 0;

  /// Tells the service which Dart function to run when a notification
  /// arrives and the app is not running.
  ///
  /// [handle] is `PluginUtilities.getCallbackHandle(fn)!.toRawHandle()` for a
  /// top-level function marked `@pragma('vm:entry-point')`. The service
  /// stores it, so it survives the app being closed; an app update can move
  /// it, so the app registers it on every start.
  Future<void> registerBackgroundHandle(int handle) =>
      channel.invokeMethod<void>('registerBackgroundHandle', <String, Object>{
        'handle': handle,
      });

  /// Called by the background function when it is finished, so the service
  /// can shut its engine down. A no-op from the app's own engine.
  Future<void> backgroundDone() => channel.invokeMethod<void>('backgroundDone');

  /// Fires when the service captured something while the app is running —
  /// the cue to drain the inbox now rather than on the next tick.
  Stream<void> get captures => _captures.stream;

  static final StreamController<void> _captures =
      StreamController<void>.broadcast(onListen: _listenForCaptures);

  static void _listenForCaptures() {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'captured') _captures.add(null);
    });
  }
}
