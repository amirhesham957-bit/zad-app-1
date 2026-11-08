/// When the customer usually leaves home and comes back, learned on this
/// phone from the home fence's own events. Opt-in, separately from street
/// alerts.
///
/// Only the summary leaves the phone: times and weekdays. There are no
/// coordinates and no trail, because none are collected: the home fence
/// already reports leaving and returning.
library;

import 'package:flutter/foundation.dart';

/// One day away from home, in the account's market zone.
typedef Outing = ({String date, int weekday, int leftMinute, int awayMinutes});

/// A day out this long or longer can be a working day.
const Duration kMinWorkDay = Duration(hours: 4);

/// Days of outings needed before a pattern is claimed.
const int kCommuteMinDays = 8;

/// A weekday needs this many samples to count as one he goes out on.
const int kCommuteMinPerWeekday = 2;

/// How far from the usual time a typical day may be, in minutes.
const int kCommuteMaxSpread = 45;

/// Outings kept on the phone.
const int kCommuteKeep = 60;

/// The usual leaving and returning.
@immutable
class CommutePattern {
  /// Creates a pattern.
  const new({
    required this.leave,
    required this.back,
    required this.days,
    required this.samples,
  });

  /// `HH:mm` he usually leaves.
  final String leave;

  /// `HH:mm` he usually returns.
  final String back;

  /// ISO weekdays, 1 to 7.
  final List<int> days;

  /// Days it was learned from.
  final int samples;

  /// Identifies the pattern, so an unchanged one is not sent again.
  String get key => '$leave|$back|${days.join(',')}';
}

int _median(List<int> values) {
  final sorted = [...values]..sort();
  return sorted[sorted.length ~/ 2];
}

/// Median distance from the middle.
int _spread(List<int> values) {
  final middle = _median(values);
  return _median([for (final v in values) (v - middle).abs()]);
}

String _hhmm(int minute) {
  final m = minute % 1440;
  final hh = (m ~/ 60).toString().padLeft(2, '0');
  final mm = (m % 60).toString().padLeft(2, '0');
  return '$hh:$mm';
}

/// The pattern in [outings], or null when there is not enough, or it is too
/// irregular to be called a routine. A short errand on a day is ignored: the
/// longest outing of each date stands for that day.
CommutePattern? commutePattern(List<Outing> outings) {
  final byDate = <String, Outing>{};
  for (final o in outings) {
    if (o.awayMinutes < kMinWorkDay.inMinutes) continue;
    final seen = byDate[o.date];
    if (seen == null || o.awayMinutes > seen.awayMinutes) byDate[o.date] = o;
  }
  if (byDate.length < kCommuteMinDays) return null;

  final perDay = <int, int>{};
  for (final o in byDate.values) {
    perDay[o.weekday] = (perDay[o.weekday] ?? 0) + 1;
  }
  final days = [
    for (final MapEntry(:key, :value) in perDay.entries)
      if (value >= kCommuteMinPerWeekday) key,
  ]..sort();
  final used = [
    for (final o in byDate.values)
      if (days.contains(o.weekday)) o,
  ];
  if (used.length < kCommuteMinDays) return null;

  final left = [for (final o in used) o.leftMinute];
  final back = [for (final o in used) o.leftMinute + o.awayMinutes];
  if (_spread(left) > kCommuteMaxSpread || _spread(back) > kCommuteMaxSpread) {
    return null;
  }
  return CommutePattern(
    leave: _hhmm(_median(left)),
    back: _hhmm(_median(back)),
    days: days,
    samples: used.length,
  );
}
