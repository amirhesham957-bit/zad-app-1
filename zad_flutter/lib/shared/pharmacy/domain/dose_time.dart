/// A time of day a dose is due.
///
/// `zad_pharmacy_items.dose_times` is a comma-separated list of 24-hour civil
/// times — `"08:00,16:00,00:00"`. Civil, not instants: the server turns each
/// one into a moment with
///
/// ```sql
/// (((now() at time zone tz)::date - days_back) + dose_time) at time zone tz
/// ```
///
/// where `tz` is `zad_market_timezone(u.country)` — the **account's** market,
/// never the device's. A client that read these against the phone's zone would
/// put a traveller's morning dose in the middle of their night, and would land
/// a midnight slot on the wrong day for everybody.
///
/// The accepted shape is the server's regex exactly:
/// `^([01]?[0-9]|2[0-3]):[0-5][0-9]$`. Which means `24:00` is **not** a time —
/// midnight is `00:00`, and a row carrying `24:00` is skipped by the cron
/// rather than shifted, so the client must skip it too or it will show a dose
/// the server will never remind anybody about.
library;

import 'package:flutter/foundation.dart';

/// One civil time of day.
@immutable
class DoseTime implements Comparable<DoseTime> {
  /// Creates a time. Both values are assumed already valid — use [parse].
  const new(this.hour, this.minute);

  /// The shape `dose_times` entries must match, copied from the SQL.
  ///
  /// Anchored, and `2[0-3]` rather than `2[0-4]`: the hour stops at 23.
  static final RegExp pattern = RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$');

  /// Reads one entry, or null when it is not a time the server would accept.
  static DoseTime? parse(String raw) {
    final trimmed = raw.trim();
    if (!pattern.hasMatch(trimmed)) return null;

    final parts = trimmed.split(':');
    return DoseTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  /// The hour, 0–23.
  final int hour;

  /// The minute, 0–59.
  final int minute;

  /// How it is stored: zero-padded `HH:mm`.
  ///
  /// Always padded, even though the regex accepts `8:00`. Writing back the
  /// padded form is what keeps a round trip through this app from changing
  /// the string the server holds.
  String get wireName =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Minutes since midnight, for ordering.
  int get sinceMidnight => hour * 60 + minute;

  @override
  int compareTo(DoseTime other) => sinceMidnight.compareTo(other.sinceMidnight);

  @override
  bool operator ==(Object other) =>
      other is DoseTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => sinceMidnight;

  @override
  String toString() => wireName;
}

/// Every valid time in a `dose_times` column, in order and without repeats.
///
/// Invalid entries are dropped rather than corrected. `23:70` is not `00:10`
/// and `24:00` is not `00:00` — a guess here schedules a medicine at a time
/// nobody chose, which is a medical error with a friendly face. Use
/// [hasInvalidDoseTime] to tell the customer their row needs fixing.
List<DoseTime> parseDoseTimes(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const <DoseTime>[];

  final times = <DoseTime>{};
  for (final entry in raw.split(',')) {
    final time = DoseTime.parse(entry);
    if (time != null) times.add(time);
  }

  return times.toList()..sort();
}

/// Whether any entry in [raw] is not a time the server would accept.
///
/// This is the client's own reading of the column. `zad_pharmacy_items` also
/// carries a `has_invalid_dose_time` flag, and the two can disagree — the flag
/// is set when a row is written, this is computed from what the column says
/// now. Both are worth having: the flag is what the cron filters on, and this
/// is what can explain to the customer why a medicine is quiet.
bool hasInvalidDoseTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return false;

  return raw
      .split(',')
      .where((e) => e.trim().isNotEmpty)
      .any((e) => DoseTime.parse(e) == null);
}
