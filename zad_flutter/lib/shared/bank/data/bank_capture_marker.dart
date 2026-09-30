/// Remembers that this device has ever captured anything.
///
/// One timestamp, and it answers the only question the health reading needs:
/// has the listener ever produced anything on this phone? A permission that is
/// on and has never yielded a single notification is the signature of a
/// service Android never bound.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/providers.dart';

/// The marker.
class BankCaptureMarker {
  /// Creates a marker over the documents box.
  const new(this._box);

  final Box<String> _box;

  static const String _key = 'bank_last_capture_at';

  /// When anything was last captured, or null if never.
  DateTime? lastCapturedAt() {
    final raw = _box.get(_key);
    return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
  }

  /// Records that something arrived.
  Future<void> sawCapture(DateTime at) =>
      _box.put(_key, at.toUtc().toIso8601String());

  static const String _grantedKey = 'bank_access_granted';
  static const String _connectedKey = 'bank_listener_connected_at';

  /// What the last check found: access granted, and when the listener last
  /// bound. A launch starts from this instead of "not granted", which drew
  /// «فعّل قراءة إشعارات البنك» for a moment on every launch until the real
  /// check answered and hid it again.
  ({bool granted, DateTime? connectedAt}) lastAccess() {
    final connected = _box.get(_connectedKey);
    return (
      granted: _box.get(_grantedKey) == 'true',
      connectedAt: connected == null
          ? null
          : DateTime.tryParse(connected)?.toUtc(),
    );
  }

  /// Keeps the check's answer for the next launch.
  Future<void> rememberAccess({
    required bool granted,
    DateTime? connectedAt,
  }) async {
    await _box.put(_grantedKey, '$granted');
    if (connectedAt == null) {
      await _box.delete(_connectedKey);
    } else {
      await _box.put(_connectedKey, connectedAt.toUtc().toIso8601String());
    }
  }
}

/// Remembers whether this device has ever captured anything.
final bankCaptureMarkerProvider = Provider<BankCaptureMarker>(
  (ref) => BankCaptureMarker(ref.watch(localStoreProvider).documents),
);
