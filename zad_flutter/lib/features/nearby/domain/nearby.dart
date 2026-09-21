/// Shops near the customer: the arithmetic, with no GPS and no network in it.
///
/// Two rules shape everything here.
///
/// * **What leaves the phone is coarse.** Coordinates are rounded to three
///   decimals — about 110 m — before they are sent anywhere, to our server or
///   to OpenStreetMap. Distances are worked out here, from the exact fix,
///   which never leaves.
/// * **A result is kept per cell.** The same rounding is the cache key, so a
///   customer who has not left the block does not ask again, and the radius
///   chips filter what is already on the phone instead of fetching.
library;

import 'dart:math' as math;

/// What kind of shop.
enum StoreKind {
  /// Supermarkets, groceries, corner shops.
  supermarket('supermarket'),

  /// Pharmacies.
  pharmacy('pharmacy');

  new(this.tag);

  /// The tag `nearby_pois` and the cache use.
  final String tag;
}

/// A point on the map.
class GeoPoint {
  /// Creates a point.
  const new(this.lat, this.lon);

  /// Latitude, degrees.
  final double lat;

  /// Longitude, degrees.
  final double lon;

  /// The point as it may leave the phone: three decimals, about 110 m.
  GeoPoint get coarse => GeoPoint(_round3(lat), _round3(lon));

  /// The cell this point falls in — the cache key.
  String get cell => '${_round3(lat)},${_round3(lon)}';

  /// Metres to [other], along the earth's surface.
  double metresTo(GeoPoint other) {
    const earth = 6371000.0;
    final dLat = _rad(other.lat - lat);
    final dLon = _rad(other.lon - lon);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(lat)) *
            math.cos(_rad(other.lat)) *
            math.pow(math.sin(dLon / 2), 2);
    return earth * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double deg) => deg * math.pi / 180;
  static double _round3(double v) => (v * 1000).roundToDouble() / 1000;
}

/// One shop.
class NearbyStore {
  /// Creates a shop.
  const new({required this.name, required this.at, required this.kind});

  /// Reads one from `nearby_pois` or the cache.
  static NearbyStore? fromJson(Object? raw, StoreKind kind) {
    if (raw is! Map) return null;
    final name = (raw['name'] as Object?)?.toString().trim() ?? '';
    final lat = _number(raw['lat']);
    final lon = _number(raw['lon']);
    if (name.isEmpty || lat == null || lon == null) return null;
    if (lat.abs() > 90 || lon.abs() > 180) return null;
    return NearbyStore(name: name, at: GeoPoint(lat, lon), kind: kind);
  }

  /// Its name.
  final String name;

  /// Where it is.
  final GeoPoint at;

  /// Supermarket or pharmacy.
  final StoreKind kind;

  /// For the cache.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'lat': at.lat,
    'lon': at.lon,
  };
}

/// A shop, and how far it is from where the customer stands.
typedef StoreDistance = ({NearbyStore store, int metres});

/// The radii the screen offers, in metres. The widest is what is fetched.
const List<int> kNearbyRadii = <int>[500, 1000, 3000];

/// [stores] within [radius] metres of [from], nearest first, one per name —
/// OpenStreetMap often has a shop twice, as a point and as a building.
List<StoreDistance> storesWithin(
  List<NearbyStore> stores, {
  required GeoPoint from,
  required int radius,
}) {
  final seen = <String>{};
  final out = <StoreDistance>[];
  final sorted = <StoreDistance>[
    for (final s in stores) (store: s, metres: from.metresTo(s.at).round()),
  ]..sort((a, b) => a.metres.compareTo(b.metres));
  for (final d in sorted) {
    if (d.metres > radius) break;
    if (seen.add(d.store.name.toLowerCase())) out.add(d);
  }
  return out;
}

/// "٣٥٠ م" or "١٫٢ كم" — display only.
String formatDistance(int metres) => metres < 1000
    ? '$metres م'
    : '${(metres / 1000).toStringAsFixed(1)} كم';

double? _number(Object? raw) => switch (raw) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s),
  _ => null,
};
