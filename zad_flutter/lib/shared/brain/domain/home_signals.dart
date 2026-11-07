/// What «حالة البيت» (`zad_home_state`, ZAD_PLAN ٣.١) knows that the phone
/// does not work out on its own: the budget's danger before it goes below
/// zero, medicines about to run out, and the season ahead (ZAD_PLAN ٦.٤).
///
/// Read from the server's row, never computed here: the phone shows what the
/// brain sees, so the brief and the brain say the same thing.
library;

import 'package:flutter/foundation.dart';

/// A medicine the server counts as running out.
typedef LowMedicine = ({String name, int days});

/// The season ahead, within three weeks.
typedef SeasonAhead = ({String kind, int inDays});

/// The parts of the home state the brief reads.
@immutable
class HomeSignals {
  /// Creates the signals.
  const new({
    this.threat,
    this.available,
    this.daysLeft,
    this.dailyLeft,
    this.currency = '',
    this.medicinesLow = const <LowMedicine>[],
    this.seasonAhead,
    this.seasonNow,
  });

  /// From `zad_home_state.state`; anything missing or malformed is absent.
  factory fromState(Map<String, dynamic> state) {
    final money = _map(state['money']);
    final health = _map(state['health']);
    final season = _map(state['season']);
    final ahead = _map(season['ahead']);
    return HomeSignals(
      threat: money['threat'] as String?,
      available: _num(money['available']),
      daysLeft: _num(money['days_left'])?.round(),
      dailyLeft: _num(money['daily_left']),
      currency: (money['currency'] as String?) ?? '',
      medicinesLow: <LowMedicine>[
        if (health['medicines_low'] case final List<dynamic> list)
          for (final m in list)
            if (m case {'name': final String name, 'days': final num days})
              if (name.trim().isNotEmpty)
                (name: name.trim(), days: days.round()),
      ],
      seasonAhead: switch ((ahead['kind'], _num(ahead['in_days']))) {
        (final String kind, final num days) => (
          kind: kind,
          inDays: days.round(),
        ),
        _ => null,
      },
      seasonNow: season['now'] as String?,
    );
  }

  /// `zad_budget_state.threat`: SAFE, WATCH, DANGER, OVER or UNKNOWN.
  final String? threat;

  /// What the period still has.
  final double? available;

  /// Days left in the period.
  final int? daysLeft;

  /// What each of those days has.
  final double? dailyLeft;

  /// The account's currency.
  final String currency;

  /// Medicines with five days or fewer left, soonest first.
  final List<LowMedicine> medicinesLow;

  /// The season ahead, if one starts within three weeks.
  final SeasonAhead? seasonAhead;

  /// The season now, if any.
  final String? seasonNow;

  static Map<String, dynamic> _map(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

  static double? _num(Object? v) => v is num ? v.toDouble() : null;
}
