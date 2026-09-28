/// Street alerts: the arithmetic, with no GPS, no clock and no network.
///
/// Kotlin's `HomePlace` + `GroceryGeofenceManager`, ported. What they do:
///
/// * **Shops.** Android watches a 120 m circle round each of the nearest
///   supermarkets and pharmacies. Walking into one asks the server
///   (`store_arrival`) what is missing at home; it answers with the list, and
///   the phone shows it.
/// * **Home.** Where the phone sleeps (sampled between 01:00 and 05:00, two
///   different nights within 150 m) is home. **Its coordinates never leave the
///   phone.** Leaving and coming back after 45 min – 18 h sends the server only
///   the time of leaving (`place_event`); it sums what was spent in between.
/// * **Moving on.** One wide circle round where the shops were looked up.
///   Leaving it means the list is for somewhere else now: look again from
///   where the phone is. Kotlin re-looked every 12 hours instead, which
///   misses a customer who went across town at noon.
library;

import 'package:timezone/timezone.dart' as tz;
import 'package:zad/features/nearby/domain/nearby.dart';
import 'package:zad_geofence/zad_geofence.dart';

/// A shop's circle. Kotlin's 120 m.
const double kStoreRadius = 120;

/// Home's circle.
const double kHomeRadius = 150;

/// The circle whose exit means "look for shops again".
const double kAreaRadius = 1500;

/// How far to look for shops. Wider than [kAreaRadius], so the shops just
/// past its edge are already watched when the phone crosses it.
const int kSearchRadius = 3000;

/// Shops per kind. Android allows 100 fences an app; two kinds, home and the
/// area stay far under.
const int kShopsPerKind = 15;

/// Shorter than this away is a trip to the corner, not an outing.
const Duration kMinOuting = Duration(minutes: 45);

/// Longer than this and it was a trip, not an outing; the server refuses it.
const Duration kMaxOuting = Duration(hours: 18);

/// One alert per shop a day, even for someone who passes it five times.
const Duration kShopCooldown = Duration(hours: 24);

/// An arrival delivered this late (phone was offline) is no longer "you are
/// near it" — dropped rather than announced.
const Duration kStaleArrival = Duration(minutes: 30);

/// Look for shops again at least this often, even without leaving the area.
const Duration kRefreshEvery = Duration(hours: 12);

/// Fence ids that are not shops.
const String kHomeFence = 'zad_home';

/// See [kAreaRadius].
const String kAreaFence = 'zad_area';

/// A place a fence stands for.
typedef FencedShop = ({String name, StoreKind kind});

/// Where the phone was one night.
typedef NightSample = ({GeoPoint at, String date});

/// Home, from the nights: the latest night and every night within
/// [kHomeRadius] of it; two different dates at least. Kotlin's `learnHome`.
GeoPoint? learnHome(List<NightSample> samples) {
  if (samples.isEmpty) return null;
  final latest = samples.last.at;
  final cluster = <NightSample>[
    for (final s in samples)
      if (s.at.metresTo(latest) <= kHomeRadius) s,
  ];
  if (cluster.map((s) => s.date).toSet().length < 2) return null;
  double mean(double Function(NightSample) f) =>
      cluster.map(f).reduce((a, b) => a + b) / cluster.length;
  return GeoPoint(mean((s) => s.at.lat), mean((s) => s.at.lon));
}

/// Whether [local] (the account's market zone) is when a phone is at home
/// asleep.
bool isNightHour(DateTime local) => local.hour >= 1 && local.hour <= 4;

/// Whether being away from [leftAt] until [now] is an outing worth a recap.
bool isOuting(DateTime? leftAt, DateTime now) {
  if (leftAt == null) return false;
  final away = now.difference(leftAt);
  return away >= kMinOuting && away <= kMaxOuting;
}

/// The next 03:00 in [zone], after [now].
DateTime nextNightSample(DateTime now, tz.Location zone) {
  final local = tz.TZDateTime.from(now, zone);
  var at = tz.TZDateTime(zone, local.year, local.month, local.day, 3);
  if (!at.isAfter(local)) {
    at = tz.TZDateTime(zone, local.year, local.month, local.day + 1, 3);
  }
  return at.toUtc();
}

/// The fences for [shops] (nearest first per kind), [home], and the area
/// round [center].
({List<Fence> fences, Map<String, FencedShop> shops}) planFences({
  required List<NearbyStore> shops,
  required GeoPoint center,
  GeoPoint? home,
}) {
  final fences = <Fence>[];
  final named = <String, FencedShop>{};
  for (final kind in StoreKind.values) {
    final nearest = storesWithin(
      [
        for (final s in shops)
          if (s.kind == kind) s,
      ],
      from: center,
      radius: kSearchRadius,
    ).take(kShopsPerKind).toList();
    for (final (i, d) in nearest.indexed) {
      final id = '${kind.tag}_$i';
      named[id] = (name: d.store.name, kind: kind);
      fences.add(
        Fence(
          id: id,
          lat: d.store.at.lat,
          lon: d.store.at.lon,
          radius: kStoreRadius,
        ),
      );
    }
  }
  if (home != null) {
    fences.add(
      Fence(
        id: kHomeFence,
        lat: home.lat,
        lon: home.lon,
        radius: kHomeRadius,
        exit: true,
      ),
    );
  }
  fences.add(
    Fence(
      id: kAreaFence,
      lat: center.lat,
      lon: center.lon,
      radius: kAreaRadius,
      enter: false,
      exit: true,
    ),
  );
  return (fences: fences, shops: named);
}

/// Everything street alerts remember, on the phone only. Read and written as
/// one blob, so the app's engine and the headless one agree.
class PlaceState {
  /// Creates a state.
  const new({
    this.enabled = false,
    this.zone = 'UTC',
    this.shops = const <String, FencedShop>{},
    this.alerted = const <String, DateTime>{},
    this.home,
    this.nights = const <NightSample>[],
    this.leftAt,
    this.refreshedAt,
    this.center,
  });

  /// Reads the blob; anything unreadable is the default.
  factory fromJson(Map<String, dynamic> json) {
    GeoPoint? point(Object? raw) {
      if (raw is! Map) return null;
      final lat = raw['lat'];
      final lon = raw['lon'];
      return lat is num && lon is num
          ? GeoPoint(lat.toDouble(), lon.toDouble())
          : null;
    }

    DateTime? time(Object? raw) => raw is num
        ? DateTime.fromMillisecondsSinceEpoch(raw.toInt(), isUtc: true)
        : null;

    final shops = <String, FencedShop>{};
    final rawShops = json['shops'];
    if (rawShops is Map) {
      for (final MapEntry(:key, :value) in rawShops.entries) {
        if (value is! Map) continue;
        final kind = StoreKind.values
            .where((k) => k.tag == value['kind'])
            .firstOrNull;
        final name = value['name'];
        if (kind != null && name is String) {
          shops[key.toString()] = (name: name, kind: kind);
        }
      }
    }
    final alerted = <String, DateTime>{};
    final rawAlerted = json['alerted'];
    if (rawAlerted is Map) {
      for (final MapEntry(:key, :value) in rawAlerted.entries) {
        final at = time(value);
        if (at != null) alerted[key.toString()] = at;
      }
    }
    final nights = <NightSample>[];
    final rawNights = json['nights'];
    if (rawNights is List) {
      for (final n in rawNights) {
        final at = point(n);
        final date = n is Map ? n['date'] : null;
        if (at != null && date is String) nights.add((at: at, date: date));
      }
    }
    return PlaceState(
      enabled: json['enabled'] == true,
      zone: json['zone'] is String ? json['zone'] as String : 'UTC',
      shops: shops,
      alerted: alerted,
      home: point(json['home']),
      nights: nights,
      leftAt: time(json['left_at']),
      refreshedAt: time(json['refreshed_at']),
      center: point(json['center']),
    );
  }

  /// Whether the customer turned street alerts on.
  final bool enabled;

  /// The account's market zone, for [isNightHour] where no provider is.
  final String zone;

  /// What each shop fence is.
  final Map<String, FencedShop> shops;

  /// When each shop (by lower-cased name) was last announced.
  final Map<String, DateTime> alerted;

  /// Home, once learned.
  final GeoPoint? home;

  /// The last nights, oldest first.
  final List<NightSample> nights;

  /// When the phone left home, while it is out.
  final DateTime? leftAt;

  /// When the shops were last looked up.
  final DateTime? refreshedAt;

  /// Where they were looked up from.
  final GeoPoint? center;

  /// A copy with the given fields replaced. [leftAt] is cleared with
  /// `clearLeftAt`, since null means "keep".
  PlaceState copyWith({
    bool? enabled,
    String? zone,
    Map<String, FencedShop>? shops,
    Map<String, DateTime>? alerted,
    GeoPoint? home,
    List<NightSample>? nights,
    DateTime? leftAt,
    bool clearLeftAt = false,
    DateTime? refreshedAt,
    GeoPoint? center,
  }) => PlaceState(
    enabled: enabled ?? this.enabled,
    zone: zone ?? this.zone,
    shops: shops ?? this.shops,
    alerted: alerted ?? this.alerted,
    home: home ?? this.home,
    nights: nights ?? this.nights,
    leftAt: clearLeftAt ? null : (leftAt ?? this.leftAt),
    refreshedAt: refreshedAt ?? this.refreshedAt,
    center: center ?? this.center,
  );

  /// The blob.
  Map<String, dynamic> toJson() {
    Map<String, double> point(GeoPoint p) => <String, double>{
      'lat': p.lat,
      'lon': p.lon,
    };
    final home = this.home;
    final center = this.center;
    return <String, dynamic>{
      'enabled': enabled,
      'zone': zone,
      'shops': <String, Object>{
        for (final MapEntry(:key, :value) in shops.entries)
          key: <String, String>{'name': value.name, 'kind': value.kind.tag},
      },
      'alerted': <String, int>{
        for (final MapEntry(:key, :value) in alerted.entries)
          key: value.millisecondsSinceEpoch,
      },
      if (home != null) 'home': point(home),
      'nights': <Object>[
        for (final n in nights)
          <String, Object>{...point(n.at), 'date': n.date},
      ],
      'left_at': ?leftAt?.millisecondsSinceEpoch,
      'refreshed_at': ?refreshedAt?.millisecondsSinceEpoch,
      if (center != null) 'center': point(center),
    };
  }
}

/// Adds tonight's sample: one per date, the last ten kept. Returns the new
/// state and whether home was learned for the first time or moved — the cue
/// to register its fence.
({PlaceState state, bool homeChanged}) recordNight(
  PlaceState state,
  GeoPoint at,
  String date,
) {
  final nights = <NightSample>[
    for (final n in state.nights)
      if (n.date != date) n,
    (at: at, date: date),
  ];
  final kept = nights.length > 10 ? nights.sublist(nights.length - 10) : nights;
  final learned = learnHome(kept);
  final previous = state.home;
  final changed =
      learned != null &&
      (previous == null || previous.metresTo(learned) > kHomeRadius / 2);
  return (
    state: state.copyWith(nights: kept, home: learned),
    homeChanged: changed,
  );
}
