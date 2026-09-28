import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/features/alerts/domain/push_alert.dart';
import 'package:zad/features/nearby/domain/nearby.dart';
import 'package:zad/features/places/application/place_engine.dart';
import 'package:zad/features/places/data/place_server.dart';
import 'package:zad/features/places/domain/places.dart';
import 'package:zad_geofence/zad_geofence.dart';

class _Host implements PlaceHost {
  final List<PlaceEvent> events = <PlaceEvent>[];
  final List<int> acked = <int>[];
  List<Fence>? registered;
  String? blob;
  DateTime? night;
  bool refuse = false;

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
  Future<void> register(List<Fence> fences) async {
    if (refuse) throw StateError('no permission');
    registered = fences;
  }

  @override
  Future<void> clear() async => registered = null;

  @override
  Future<String?> readState() async => blob;

  @override
  Future<void> writeState(String state) async => blob = state;

  @override
  Future<void> scheduleNight(DateTime at) async => night = at;

  @override
  Future<void> cancelNight() async => night = null;
}

class _Server implements PlaceServer {
  final List<String> arrivals = <String>[];
  final List<DateTime> backHomes = <DateTime>[];
  final List<GeoPoint> locations = <GeoPoint>[];
  PushAlert? reply = const PushAlert(title: 'أنت جنب', body: '• لبن');
  bool offline = false;

  @override
  Future<PushAlert?> storeArrival({
    required String name,
    required StoreKind kind,
  }) async {
    if (offline) throw StateError('offline');
    arrivals.add(name);
    return reply;
  }

  @override
  Future<void> backHome(DateTime leftAt) async {
    if (offline) throw StateError('offline');
    backHomes.add(leftAt);
  }

  @override
  Future<void> saveLastLocation(GeoPoint coarse) async => locations.add(coarse);
}

void main() {
  setUpAll(tz_data.initializeTimeZones);

  const home = GeoPoint(30.0444, 31.2357);
  final now = DateTime.utc(2026, 9, 1, 12);
  late _Host host;
  late _Server server;
  late List<PushAlert> shown;
  late List<GeoPoint> lookedUp;
  late PlaceEngine engine;

  var nextKey = 1;
  PlaceEvent event(
    String fence,
    PlaceTransition t,
    DateTime at, {
    GeoPoint? where,
  }) => PlaceEvent(
    key: nextKey++,
    fence: fence,
    transition: t,
    at: at,
    lat: where?.lat,
    lon: where?.lon,
  );

  void seed(PlaceState state) => host.blob = jsonEncode(state.toJson());

  setUp(() {
    host = _Host();
    server = _Server();
    shown = <PushAlert>[];
    lookedUp = <GeoPoint>[];
    engine = PlaceEngine(
      host: host,
      server: server,
      findShops: (at, kind) async {
        lookedUp.add(at);
        return <NearbyStore>[
          NearbyStore(
            name: kind == StoreKind.pharmacy ? 'العزبي' : 'كارفور',
            at: at,
            kind: kind,
          ),
        ];
      },
      notify: (a) async => shown.add(a),
      now: () => now,
    );
  });

  final fresh = PlaceState(
    enabled: true,
    zone: 'Africa/Cairo',
    shops: const <String, FencedShop>{
      'supermarket_0': (name: 'كارفور', kind: StoreKind.supermarket),
      'pharmacy_0': (name: 'العزبي', kind: StoreKind.pharmacy),
    },
    refreshedAt: now,
    center: home,
  );

  test('enable registers shops, home-less area, and the night alarm', () async {
    await engine.enable(at: home, zone: 'Africa/Cairo');
    expect(host.state.enabled, isTrue);
    expect(host.registered!.map((f) => f.id), <String>[
      'supermarket_0',
      'pharmacy_0',
      kAreaFence,
    ]);
    // Coarse point to the shop finder and the server; exact stays here.
    expect(lookedUp.first.lat, home.coarse.lat);
    expect(server.locations.single.lat, home.coarse.lat);
    expect(host.night, DateTime.utc(2026, 9, 2));
  });

  test('entering a shop asks the server and shows its answer', () async {
    seed(fresh);
    host.events.add(event('supermarket_0', PlaceTransition.enter, now));
    await engine.handlePending();
    expect(server.arrivals, <String>['كارفور']);
    expect(shown.single.body, '• لبن');
    expect(host.acked, hasLength(1));
    expect(host.state.alerted.keys, contains('كارفور'));
  });

  test(
    'two shops at once are one alert; the same shop is quiet for a day',
    () async {
      seed(fresh);
      host.events
        ..add(event('supermarket_0', PlaceTransition.enter, now))
        ..add(event('pharmacy_0', PlaceTransition.enter, now));
      await engine.handlePending();
      expect(server.arrivals, <String>['كارفور']);

      host.events.add(event('supermarket_0', PlaceTransition.enter, now));
      await engine.handlePending();
      expect(server.arrivals, <String>['كارفور'], reason: 'cooldown');
    },
  );

  test('nothing to say from the server shows nothing', () async {
    seed(fresh);
    server.reply = null;
    host.events.add(event('supermarket_0', PlaceTransition.enter, now));
    await engine.handlePending();
    expect(server.arrivals, hasLength(1));
    expect(shown, isEmpty);
  });

  test('an arrival delivered late is dropped, not announced', () async {
    seed(fresh);
    host.events.add(
      event(
        'supermarket_0',
        PlaceTransition.enter,
        now.subtract(const Duration(minutes: 31)),
      ),
    );
    await engine.handlePending();
    expect(server.arrivals, isEmpty);
    expect(host.acked, hasLength(1));
  });

  test('leaving and coming back after an outing sends only the time', () async {
    seed(fresh.copyWith(home: home));
    final left = now.subtract(const Duration(hours: 2));
    host.events
      ..add(event(kHomeFence, PlaceTransition.exit, left))
      ..add(event(kHomeFence, PlaceTransition.enter, now));
    await engine.handlePending();
    expect(server.backHomes, <DateTime>[left]);
    expect(host.state.leftAt, isNull);
  });

  test('a short trip is not an outing', () async {
    seed(fresh.copyWith(home: home));
    host.events
      ..add(
        event(
          kHomeFence,
          PlaceTransition.exit,
          now.subtract(const Duration(minutes: 20)),
        ),
      )
      ..add(event(kHomeFence, PlaceTransition.enter, now));
    await engine.handlePending();
    expect(server.backHomes, isEmpty);
    expect(host.state.leftAt, isNull);
  });

  test(
    'offline coming home keeps the event and the leaving for later',
    () async {
      seed(fresh.copyWith(home: home));
      final left = now.subtract(const Duration(hours: 2));
      final exit = event(kHomeFence, PlaceTransition.exit, left);
      final enter = event(kHomeFence, PlaceTransition.enter, now);
      host.events.addAll(<PlaceEvent>[exit, enter]);
      server.offline = true;
      await engine.handlePending();
      expect(host.acked, <int>[exit.key]);
      expect(host.state.leftAt, left);

      server.offline = false;
      await engine.handlePending();
      expect(server.backHomes, <DateTime>[left]);
      expect(host.acked, containsAll(<int>[exit.key, enter.key]));
    },
  );

  test('leaving the area looks for shops from where the phone is', () async {
    seed(fresh);
    const there = GeoPoint(30.07, 31.25);
    host.events.add(event(kAreaFence, PlaceTransition.exit, now, where: there));
    await engine.handlePending();
    expect(lookedUp.first.lat, there.coarse.lat);
    expect(host.state.center?.lat, there.lat);
  });

  test('two night samples at home learn it and register its fence', () async {
    seed(fresh);
    // 03:00 Cairo = 00:00 UTC.
    host.events
      ..add(
        event(
          ZadGeofence.nightFence,
          PlaceTransition.night,
          DateTime.utc(2026, 8, 30),
          where: home,
        ),
      )
      ..add(
        event(
          ZadGeofence.nightFence,
          PlaceTransition.night,
          DateTime.utc(2026, 8, 31),
          where: home,
        ),
      );
    await engine.handlePending();
    expect(host.state.home, isNotNull);
    expect(host.registered!.map((f) => f.id), contains(kHomeFence));
  });

  test('a sample outside the night hours is ignored', () async {
    seed(fresh);
    for (final day in <int>[30, 31]) {
      host.events.add(
        event(
          ZadGeofence.nightFence,
          PlaceTransition.night,
          // 15:00 Cairo.
          DateTime.utc(2026, 8, day, 12),
          where: home,
        ),
      );
    }
    await engine.handlePending();
    expect(host.state.nights, isEmpty);
  });

  test('turned off: events are dropped without a word', () async {
    seed(fresh.copyWith(enabled: false));
    host.events.add(event('supermarket_0', PlaceTransition.enter, now));
    await engine.handlePending();
    expect(server.arrivals, isEmpty);
    expect(host.acked, hasLength(1));
  });

  test('disable clears fences and the alarm but keeps home', () async {
    seed(fresh.copyWith(home: home));
    host
      ..registered = <Fence>[]
      ..night = now;
    await engine.disable();
    expect(host.registered, isNull);
    expect(host.night, isNull);
    expect(host.state.enabled, isFalse);
    expect(host.state.home, isNotNull);
  });

  test('enable surfaces a refusal', () async {
    host.refuse = true;
    await expectLater(
      engine.enable(at: home, zone: 'Africa/Cairo'),
      throwsStateError,
    );
  });

  group('storeArrivalAlert', () {
    test('reads title and body', () {
      final alert = storeArrivalAlert(<String, Object>{
        'title': '💊 أنت جنب «العزبي»',
        'body': '• بنادول',
      }, StoreKind.pharmacy);
      expect(alert?.destination, AlertDestination.pharmacy);
    });

    test('nothing to say without them', () {
      expect(
        storeArrivalAlert(<String, Object>{
          'ok': true,
          'reason': 'nothing_missing',
        }, StoreKind.supermarket),
        isNull,
      );
    });
  });
}
