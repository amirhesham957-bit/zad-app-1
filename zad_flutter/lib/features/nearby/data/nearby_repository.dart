/// The shops last found, kept on the phone.
///
/// One snapshot: the coarse point it was asked about, when, and both lists,
/// each fetched once at the widest radius. It is reused while the customer is
/// within `reuseWithin` of that point and it is younger than `freshFor` —
/// shops do not move, and a list fetched at 3 km still covers a 1 km chip
/// after a short walk. Only the coarse point is stored; the exact fix stays
/// in memory.
library;

import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/features/nearby/data/nearby_remote.dart';
import 'package:zad/features/nearby/domain/nearby.dart';

/// What was found around one point.
class NearbySnapshot {
  /// Creates a snapshot.
  const new({
    required this.center,
    required this.fetchedAt,
    required this.supermarkets,
    required this.pharmacies,
  });

  /// Reads one back out of the cache.
  static NearbySnapshot? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final lat = (raw['lat'] as num?)?.toDouble();
    final lon = (raw['lon'] as num?)?.toDouble();
    final at = DateTime.tryParse(raw['fetched_at']?.toString() ?? '');
    if (lat == null || lon == null || at == null) return null;
    List<NearbyStore> read(Object? list, StoreKind kind) => <NearbyStore>[
      if (list is List)
        for (final s in list) ?NearbyStore.fromJson(s, kind),
    ];
    return NearbySnapshot(
      center: GeoPoint(lat, lon),
      fetchedAt: at.toUtc(),
      supermarkets: read(raw['supermarkets'], StoreKind.supermarket),
      pharmacies: read(raw['pharmacies'], StoreKind.pharmacy),
    );
  }

  /// The coarse point asked about.
  final GeoPoint center;

  /// When.
  final DateTime fetchedAt;

  /// Supermarkets and groceries.
  final List<NearbyStore> supermarkets;

  /// Pharmacies.
  final List<NearbyStore> pharmacies;

  /// For the cache.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'lat': center.lat,
    'lon': center.lon,
    'fetched_at': fetchedAt.toIso8601String(),
    'supermarkets': <Map<String, dynamic>>[
      for (final s in supermarkets) s.toJson(),
    ],
    'pharmacies': <Map<String, dynamic>>[
      for (final s in pharmacies) s.toJson(),
    ],
  };
}

/// Holds the shops.
class NearbyRepository {
  /// Creates a repository.
  const new({
    required Box<String> cache,
    required NearbyRemote remote,
    required DateTime Function() now,
  }) : _cache = cache,
       _remote = remote,
       _now = now;

  final Box<String> _cache;
  final NearbyRemote _remote;
  final DateTime Function() _now;

  /// How far the customer may move before the list is asked for again.
  static const int reuseWithin = 500;

  /// How long a list stays good.
  static const Duration freshFor = Duration(hours: 24);

  /// How far out each list is fetched — the widest chip.
  static const int fetchRadius = 3000;

  static const String _key = 'nearby_stores';

  /// The last snapshot, or null.
  NearbySnapshot? cached() {
    final raw = _cache.get(_key);
    if (raw == null) return null;
    try {
      return NearbySnapshot.fromJson(jsonDecode(raw));
    } on Object {
      return null;
    }
  }

  /// Whether the last snapshot still answers for [at].
  bool covers(GeoPoint at) {
    final last = cached();
    if (last == null) return false;
    final age = _now().toUtc().difference(last.fetchedAt);
    return age < freshFor && last.center.metresTo(at) <= reuseWithin;
  }

  /// The shops around [at]: the kept snapshot when it covers [at], otherwise
  /// both lists fetched for the coarse point and kept.
  Future<NearbySnapshot> around(GeoPoint at) async {
    if (covers(at)) return cached()!;

    final coarse = at.coarse;
    final lists = await Future.wait(<Future<List<NearbyStore>>>[
      _remote.stores(
        at: coarse,
        kind: StoreKind.supermarket,
        radius: fetchRadius,
      ),
      _remote.stores(at: coarse, kind: StoreKind.pharmacy, radius: fetchRadius),
    ]);
    final snapshot = NearbySnapshot(
      center: coarse,
      fetchedAt: _now().toUtc(),
      supermarkets: lists[0],
      pharmacies: lists[1],
    );
    await _cache.put(_key, jsonEncode(snapshot.toJson()));
    return snapshot;
  }
}
