/// The zone the account keeps its calendar in.
///
/// Every civil-time question the app asks — which day a dose belongs to, which
/// day a carton expires on, which period a transaction falls in — has to be
/// asked in the **account's market zone**, because that is the zone the server
/// answers in. The device's own zone is never the answer: a customer in Cairo
/// travelling through Dubai still takes their eight o'clock tablet at eight in
/// Cairo, and the server's reminder says so.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/period/market_calendar.dart';
import 'package:zad/data/providers.dart';

/// The account's market zone, as an IANA name.
///
/// Read in the order that best matches the server:
///
/// 1. `marketTimeZone(country)` from the cached settings row — the literal
///    mirror of `zad_market_timezone(u.country)`, which is exactly what
///    `zad_enqueue_missed_doses` feeds into its slot arithmetic;
/// 2. the `timezone` the last budget snapshot came back with, which the server
///    computed the same way and which is present even before the settings row
///    has been fetched;
/// 3. `UTC` — the SQL's own fallback for an unknown country, and deliberately
///    not the device's zone.
final accountTimeZoneProvider = Provider<String>((ref) {
  final country = ref.watch(settingsRepositoryProvider).cached()?.country;
  if (country != null && country.isNotEmpty) return marketTimeZone(country);

  final fromBudget = ref.watch(budgetRepositoryProvider).cached()?.timeZone;
  if (fromBudget != null && fromBudget.isNotEmpty) return fromBudget;

  return 'UTC';
});
