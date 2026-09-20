/// Remembers that this device has ever captured anything.
///
/// One timestamp, and it answers the only question the health reading needs:
/// has the listener ever produced anything on this phone? A permission that is
/// on and has never yielded a single notification is the signature of a
/// service Android never bound.
library;

import 'package:hive_ce_flutter/hive_flutter.dart';

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
}
