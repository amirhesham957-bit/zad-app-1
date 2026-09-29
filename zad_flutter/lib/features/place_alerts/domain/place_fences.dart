/// «فكّرني لما أوصل»: which shops to watch, and what a fence id carries.
///
/// Kotlin's GroceryGeofenceManager: the nearest supermarkets and pharmacies
/// around the customer become geofences; stopping at one tells the server
/// (`store_arrival`), which sends what the home is short of. Pure: no GPS, no
/// network, no plugin.
library;

import 'package:zad/features/nearby/domain/nearby.dart';

/// How close counts as being at the shop.
const double kFenceRadiusMetres = 120;

/// How far around the customer shops are looked for.
const int kFenceSearchRadiusMetres = 3000;

/// Android allows 100 geofences per app; this is well inside it and enough
/// for a neighbourhood.
const int kMaxFences = 20;

/// How far the customer must move before the fences are looked for again.
const double kRefreshAfterMetres = 1500;

const String _prefix = 'zad';

/// One shop to watch.
typedef FenceSpec = ({String id, GeoPoint at, StoreKind kind, String name});

/// The nearest [kMaxFences] of [stores] to [here], as fences. Two shops with
/// the same name and kind (a chain's branches) keep distinct ids.
List<FenceSpec> pickFences(List<NearbyStore> stores, GeoPoint here) {
  final sorted = [...stores]
    ..sort((a, b) => here.metresTo(a.at).compareTo(here.metresTo(b.at)));
  final out = <FenceSpec>[];
  for (final s in sorted.take(kMaxFences)) {
    out.add((
      id: fenceId(s.kind, s.name, out.length),
      at: s.at,
      kind: s.kind,
      name: s.name,
    ));
  }
  return out;
}

/// `zad|<kind>|<n>|<name>` — what the arrival handler needs, with no lookup:
/// it runs with the app closed.
String fenceId(StoreKind kind, String name, int n) {
  final clean = name
      .replaceAll('|', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final short = clean.length > 60 ? clean.substring(0, 60) : clean;
  return '$_prefix|${kind.tag}|$n|$short';
}

/// The shop a fence id names, or null for one that is not ours.
({StoreKind kind, String name})? fenceStore(String id) {
  final parts = id.split('|');
  if (parts.length < 4 || parts[0] != _prefix) return null;
  final kind = StoreKind.values.where((k) => k.tag == parts[1]).firstOrNull;
  final name = parts.sublist(3).join('|').trim();
  if (kind == null || name.isEmpty) return null;
  return (kind: kind, name: name);
}

/// Whether the fences drawn around [last] are stale where the customer is
/// now.
bool fencesStale(GeoPoint? last, GeoPoint now) =>
    last == null || last.metresTo(now) > kRefreshAfterMetres;
