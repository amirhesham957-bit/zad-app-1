/// Where the shops are: our server first, OpenStreetMap when it has nothing.
///
/// `nearby_pois` on `zad-core-intelligence` asks LocationIQ with the server's
/// key and caches per ~110 m cell, so neighbours share one lookup. It answers
/// an empty list when the key is not set or LocationIQ fails; then the phone
/// asks Overpass (OpenStreetMap, free, no key) itself — Kotlin's order too.
///
/// Both are sent the coarse point only. Neither is a model call.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/features/nearby/domain/nearby.dart';

/// Finds shops around a point.
abstract interface class NearbyRemote {
  /// Shops of [kind] within [radius] metres of [at], which is already coarse.
  /// Throws when neither source could be reached.
  Future<List<NearbyStore>> stores({
    required GeoPoint at,
    required StoreKind kind,
    required int radius,
  });
}

/// Calls `zad-core-intelligence` with [body] and returns what it answered.
typedef ServerCall = Future<Object?> Function(Map<String, dynamic> body);

/// [ServerCall] over a Supabase client.
ServerCall supabaseServerCall(SupabaseClient client) =>
    (body) async => (await client.functions.invoke(
      'zad-core-intelligence',
      body: body,
    )).data;

/// The real one.
class ServerThenOverpassRemote implements NearbyRemote {
  /// Creates the remote.
  const new(this._server, this._http);

  final ServerCall _server;
  final http.Client _http;

  static final Uri _overpass = Uri.parse(
    'https://overpass-api.de/api/interpreter',
  );

  @override
  Future<List<NearbyStore>> stores({
    required GeoPoint at,
    required StoreKind kind,
    required int radius,
  }) async {
    var serverFailed = false;
    try {
      final fromServer = await _fromServer(at, kind, radius);
      if (fromServer.isNotEmpty) return fromServer;
    } on Object {
      serverFailed = true;
    }
    try {
      return await _fromOverpass(at, kind, radius);
    } on Object catch (error) {
      // Both failed: say so, rather than an empty list that reads as "no
      // shops near you". A server that answered "none" and an Overpass that
      // failed is still a failure — the "none" may be a missing key.
      throw StateError(
        'no shop source answered (server ${serverFailed ? 'failed' : 'empty'},'
        ' overpass: $error)',
      );
    }
  }

  Future<List<NearbyStore>> _fromServer(
    GeoPoint at,
    StoreKind kind,
    int radius,
  ) async {
    final data = await _server(<String, dynamic>{
      'action': 'nearby_pois',
      'payload': <String, dynamic>{
        'lat': at.lat,
        'lon': at.lon,
        'tag': kind.tag,
        'radius_meters': radius,
      },
    });
    if (data is! Map || data['stores'] is! List) return const <NearbyStore>[];
    return <NearbyStore>[
      for (final raw in data['stores'] as List)
        ?NearbyStore.fromJson(raw, kind),
    ];
  }

  Future<List<NearbyStore>> _fromOverpass(
    GeoPoint at,
    StoreKind kind,
    int radius,
  ) async {
    final filter = switch (kind) {
      StoreKind.supermarket =>
        'nwr["shop"~"supermarket|convenience|grocery"]'
            '(around:$radius,${at.lat},${at.lon});',
      StoreKind.pharmacy =>
        'nwr["amenity"="pharmacy"](around:$radius,${at.lat},${at.lon});',
    };
    final response = await _http
        .post(
          _overpass,
          headers: <String, String>{'User-Agent': 'Zad/1.0 (family app)'},
          body: <String, String>{
            'data': '[out:json][timeout:15];($filter);out center 40;',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('overpass answered ${response.statusCode}');
    }

    final json = jsonDecode(utf8.decode(response.bodyBytes));
    final elements = json is Map ? json['elements'] : null;
    if (elements is! List) return const <NearbyStore>[];
    return <NearbyStore>[
      for (final e in elements)
        if (e is Map)
          ?NearbyStore.fromJson(<String, Object?>{
            'name': (e['tags'] as Map?)?['name'],
            // A way or a relation has its point under "center".
            'lat': e['lat'] ?? (e['center'] as Map?)?['lat'],
            'lon': e['lon'] ?? (e['center'] as Map?)?['lon'],
          }, kind),
    ];
  }
}
