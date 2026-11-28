import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/features/places/background/place_background_main.dart';
import 'package:zad/shared/alerts/domain/push_alert.dart';
import 'package:zad/shared/nearby/domain/nearby.dart';
import 'package:zad/shared/places/application/place_engine.dart';
import 'package:zad/shared/places/domain/commute.dart';
import 'package:zad/shared/places/domain/places.dart';
import 'package:zad_geofence/zad_geofence.dart';

class _Host implements PlaceHost {
  final List<PlaceEvent> events = <PlaceEvent>[];
  final List<int> acked = <int>[];
  List<Fence>? registered;
  String? blob;

  PlaceState get state =>
      PlaceState.fromJson(jsonDecode(blob!) as Map<String, dynamic>);

  @override
  Future<List<PlaceEvent>> peek() async => <PlaceEvent>[
    for (final e in events)
      if (!acked.contains(e.key)) e,
  ];

  @override
  Future<void> acknowledge(Iterable<int> keys) async => acked.addAll(keys);

  @override
  Future<void> register(List<Fence> fences) async => registered = fences;

  @override
  Future<void> clear() async => registered = null;

  @override
  Future<String?> readState() async => blob;

  @override
  Future<void> writeState(String state) async => blob = state;

  @override
  Future<void> scheduleNight(DateTime at) async {}

  @override
  Future<void> cancelNight() async {}
}

class _Server implements PlaceServer {
  final List<DateTime> backHomes = <DateTime>[];

  @override
  Future<PushAlert?> storeArrival({
    required String name,
    required StoreKind kind,
    GeoPoint? at,
  }) async => null;

  @override
  Future<void> backHome(DateTime leftAt) async => backHomes.add(leftAt);

  @override
  Future<void> saveLastLocation(GeoPoint coarse) async {}

  @override
  Future<void> commuteSummary(CommutePattern? pattern) async {}

  @override
  Future<void> zoneEvent({
    required String zoneId,
    required PlaceTransition transition,
    required DateTime at,
  }) async {}
}

void main() {
  setUpAll(tz_data.initializeTimeZones);

  const home = GeoPoint(30.0444, 31.2357);
  final now = DateTime.utc(2026, 9, 1, 12);
  late _Host host;
  late List<Uri> requests;
  late List<PushAlert> shown;
  late PlaceEngine headless;
  var key = 1;

  PlaceEvent event(
    String fence,
    PlaceTransition t,
    DateTime at, {
    GeoPoint? where,
  }) => PlaceEvent(
    key: key++,
    fence: fence,
    transition: t,
    at: at,
    lat: where?.lat,
    lon: where?.lon,
  );

  setUp(() {
    host = _Host()
      ..blob = jsonEncode(
        PlaceState(
          enabled: true,
          zone: 'Africa/Cairo',
          home: home,
          refreshedAt: now.subtract(const Duration(hours: 1)),
          center: home,
        ).toJson(),
      );
    requests = <Uri>[];
    shown = <PushAlert>[];
    final overpass = MockClient((request) async {
      requests.add(request.url);
      return http.Response(
        jsonEncode(<String, Object?>{
          'elements': <Object?>[
            <String, Object?>{
              'lat': 30.05,
              'lon': 31.24,
              'tags': <String, Object?>{'name': 'كارفور'},
            },
          ],
        }),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    // No Supabase client: the saved access token is expired.
    headless = backgroundPlaceEngine(
      host: host,
      client: null,
      httpClient: overpass,
      notify: (a) async => shown.add(a),
      now: () => now,
    );
  });

  test('an expired session still runs the local work', () async {
    const there = GeoPoint(30.07, 31.25);
    host.events.add(event(kAreaFence, PlaceTransition.exit, now, where: there));

    await headless.handlePending();

    // The area-exit was handled with no server: shops re-planned from
    // Overpass only, fences registered, event acknowledged.
    expect(host.acked, hasLength(1));
    expect(requests, isNotEmpty);
    expect(requests.every((u) => u.host == 'overpass-api.de'), isTrue);
    expect(host.registered, isNotEmpty);
    expect(host.state.center?.lat, there.lat);
    expect(host.state.center?.lon, there.lon);
  });

  test('a visit that cannot be sent waits; the app sends it once', () async {
    final left = now.subtract(const Duration(hours: 2));
    final exit = event(kHomeFence, PlaceTransition.exit, left);
    final enter = event(kHomeFence, PlaceTransition.enter, now);
    host.events.addAll(<PlaceEvent>[exit, enter]);

    await headless.handlePending();
    // Queued: leaving remembered in the blob, the arrival still in the inbox.
    expect(host.acked, <int>[exit.key]);
    expect(host.state.leftAt, left);
    expect(shown, isEmpty);

    // Headless runs again with no session: still nothing sent, still queued.
    await headless.handlePending();
    expect(host.acked, <int>[exit.key]);

    final server = _Server();
    final app = PlaceEngine(
      host: host,
      server: server,
      findShops: (at, kind) async => const <NearbyStore>[],
      notify: (a) async => shown.add(a),
      now: () => now,
    );
    await app.handlePending();
    await app.handlePending();
    expect(server.backHomes, <DateTime>[left]);
    expect(host.acked, containsAll(<int>[exit.key, enter.key]));
    expect(host.state.leftAt, isNull);
  });

  test(
    'a shop arrival with no session shows nothing, sets no cooldown',
    () async {
      host.blob = jsonEncode(
        PlaceState(
          enabled: true,
          zone: 'Africa/Cairo',
          shops: const <String, FencedShop>{
            'supermarket_0': (name: 'كارفور', kind: StoreKind.supermarket),
          },
          refreshedAt: now.subtract(const Duration(hours: 1)),
          center: home,
        ).toJson(),
      );
      host.events.add(event('supermarket_0', PlaceTransition.enter, now));

      await headless.handlePending();

      expect(shown, isEmpty);
      expect(host.state.alerted, isEmpty);
    },
  );
}
