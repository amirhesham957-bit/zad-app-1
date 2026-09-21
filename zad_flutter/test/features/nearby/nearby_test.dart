// Shops near the customer, without draining a battery or leaking a position.
//
// Pinned: only the coarse point (three decimals, ~110 m) ever leaves the
// phone; a list is reused within 500 m and a day, and the radius chips never
// fetch; OpenStreetMap is asked only when our server has nothing, and a
// failure of both is a failure, not "no shops"; and on open the tab never
// prompts for permission and never takes a new fix — only a tap does, once.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/inventory/data/inventory_remote.dart';
import 'package:zad/features/inventory/data/shopping_list_repository.dart';
import 'package:zad/features/nearby/application/nearby_controller.dart';
import 'package:zad/features/nearby/data/location_source.dart';
import 'package:zad/features/nearby/data/nearby_remote.dart';
import 'package:zad/features/nearby/data/nearby_repository.dart';
import 'package:zad/features/nearby/domain/nearby.dart';
import 'package:zad/features/pharmacy/data/pharmacy_remote.dart';
import 'package:zad/features/pharmacy/data/pharmacy_repository.dart';

const GeoPoint _home = GeoPoint(30.044420, 31.235712);

class _Shops implements NearbyRemote {
  final List<(GeoPoint, StoreKind, int)> asked = <(GeoPoint, StoreKind, int)>[];
  Exception? failWith;

  @override
  Future<List<NearbyStore>> stores({
    required GeoPoint at,
    required StoreKind kind,
    required int radius,
  }) async {
    asked.add((at, kind, radius));
    if (failWith case final e?) throw e;
    return <NearbyStore>[
      NearbyStore(
        name: kind == StoreKind.supermarket ? 'كارفور' : 'صيدلية العزبي',
        at: const GeoPoint(30.0470, 31.2357), // ~290 m north
        kind: kind,
      ),
      NearbyStore(
        name: kind == StoreKind.supermarket ? 'خير زمان' : 'صيدلية سيف',
        at: const GeoPoint(30.0600, 31.2357), // ~1.7 km north
        kind: kind,
      ),
    ];
  }
}

class _Phone implements LocationSource {
  LocationAccess accessIs = LocationAccess.granted;
  LocationAccess afterAsking = LocationAccess.granted;
  Fix? last;
  Fix? fresh;
  final List<String> calls = <String>[];

  @override
  Future<LocationAccess> access() async {
    calls.add('access');
    return accessIs;
  }

  @override
  Future<LocationAccess> request() async {
    calls.add('request');
    return accessIs = afterAsking;
  }

  @override
  Future<Fix?> lastKnown() async {
    calls.add('lastKnown');
    return last;
  }

  @override
  Future<Fix?> current() async {
    calls.add('current');
    return fresh;
  }

  @override
  Future<void> openSettings() async => calls.add('settings');

  @override
  Future<void> openLocationSettings() async => calls.add('locationSettings');
}

class _Nothing implements ShoppingListRemote, PharmacyRemote {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  group('the arithmetic', () {
    test('what leaves the phone is three decimals', () {
      expect(_home.coarse.lat, 30.044);
      expect(_home.coarse.lon, 31.236);
      expect(_home.cell, '30.044,31.236');
    });

    test('distances are real distances', () {
      // A hundredth of a degree of latitude is about 1.11 km everywhere.
      final d = const GeoPoint(30, 31).metresTo(const GeoPoint(30.01, 31));
      expect(d, closeTo(1112, 5));
    });

    test('within a radius, nearest first, each shop once', () {
      const a = NearbyStore(
        name: 'Carrefour',
        at: GeoPoint(30.0470, 31.2357),
        kind: StoreKind.supermarket,
      );
      const twice = NearbyStore(
        name: 'carrefour',
        at: GeoPoint(30.0471, 31.2357),
        kind: StoreKind.supermarket,
      );
      const far = NearbyStore(
        name: 'Far',
        at: GeoPoint(30.0600, 31.2357),
        kind: StoreKind.supermarket,
      );
      final near = storesWithin(
        <NearbyStore>[far, twice, a],
        from: _home,
        radius: 1000,
      );
      expect(near.map((d) => d.store.name), <String>['Carrefour']);
      expect(near.single.metres, closeTo(287, 5));
    });

    test('a shop with no name or an impossible place is not a shop', () {
      expect(
        NearbyStore.fromJson(<String, dynamic>{
          'name': '',
          'lat': 1,
          'lon': 1,
        }, StoreKind.pharmacy),
        isNull,
      );
      expect(
        NearbyStore.fromJson(<String, dynamic>{
          'name': 'x',
          'lat': 91,
          'lon': 1,
        }, StoreKind.pharmacy),
        isNull,
      );
    });
  });

  group('asking for shops', () {
    Future<Object?> Function(Map<String, dynamic>) server(Object? answer) =>
        (_) async => answer;

    test('our server first; OpenStreetMap only when it has nothing', () async {
      var overpassCalls = 0;
      final remote = ServerThenOverpassRemote(
        server(<String, dynamic>{
          'stores': <Object?>[
            <String, dynamic>{'name': 'كارفور', 'lat': 30.047, 'lon': 31.235},
          ],
        }),
        MockClient((_) async {
          overpassCalls++;
          return http.Response('{}', 200);
        }),
      );

      final shops = await remote.stores(
        at: _home.coarse,
        kind: StoreKind.supermarket,
        radius: 3000,
      );
      expect(shops.single.name, 'كارفور');
      expect(overpassCalls, 0);
    });

    test('OpenStreetMap: points and buildings, at the coarse point', () async {
      String? sent;
      final remote = ServerThenOverpassRemote(
        server(<String, dynamic>{'stores': <Object?>[]}),
        MockClient((request) async {
          sent = request.body;
          return http.Response.bytes(
            utf8.encode(
              jsonEncode(<String, dynamic>{
                'elements': <Object?>[
                  <String, dynamic>{
                    'lat': 30.047,
                    'lon': 31.235,
                    'tags': <String, dynamic>{'name': 'صيدلية العزبي'},
                  },
                  <String, dynamic>{
                    'center': <String, dynamic>{'lat': 30.05, 'lon': 31.24},
                    'tags': <String, dynamic>{'name': 'صيدلية سيف'},
                  },
                  <String, dynamic>{'lat': 30.05, 'lon': 31.24},
                ],
              }),
            ),
            200,
          );
        }),
      );

      final shops = await remote.stores(
        at: _home.coarse,
        kind: StoreKind.pharmacy,
        radius: 3000,
      );
      expect(shops.map((s) => s.name), <String>['صيدلية العزبي', 'صيدلية سيف']);
      expect(Uri.decodeQueryComponent(sent!), contains('30.044,31.236'));
    });

    test('both failing is a failure, not "no shops near you"', () async {
      final remote = ServerThenOverpassRemote(
        (_) async => throw const SocketException('offline'),
        MockClient((_) async => http.Response('busy', 429)),
      );

      await expectLater(
        remote.stores(
          at: _home.coarse,
          kind: StoreKind.pharmacy,
          radius: 3000,
        ),
        throwsStateError,
      );
    });
  });

  group('on the phone', () {
    late Directory dir;
    late Box<String> documents;
    late Box<String> shoppingBox;
    late Box<String> pharmacyBox;
    late _Shops shops;
    late _Phone phone;
    late DateTime now;
    var run = 0;

    setUp(() async {
      run++;
      dir = await Directory.systemTemp.createTemp('zad_nearby_test');
      Hive.init(dir.path);
      documents = await Hive.openBox<String>('documents$run');
      shoppingBox = await Hive.openBox<String>('shopping$run');
      pharmacyBox = await Hive.openBox<String>('pharmacy$run');
      shops = _Shops();
      phone = _Phone();
      now = DateTime.utc(2026, 9, 21, 18);
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });

    NearbyRepository repository() =>
        NearbyRepository(cache: documents, remote: shops, now: () => now);

    group('the kept list', () {
      test('is asked for at the coarse point, at the widest radius', () async {
        await repository().around(_home);

        expect(shops.asked.map((a) => (a.$1.lat, a.$1.lon, a.$3)).toSet(), {
          (30.044, 31.236, 3000),
        });
        expect(shops.asked.map((a) => a.$2), <StoreKind>[
          StoreKind.supermarket,
          StoreKind.pharmacy,
        ]);
        // What is stored is the coarse point too.
        expect(repository().cached()!.center.lat, 30.044);
      });

      test('is reused a short walk away, and asked again further', () async {
        await repository().around(_home);
        await repository().around(const GeoPoint(30.0470, 31.2357)); // ~300 m
        expect(shops.asked, hasLength(2));

        await repository().around(const GeoPoint(30.0520, 31.2357)); // ~850 m
        expect(shops.asked, hasLength(4));
      });

      test('is asked again after a day', () async {
        await repository().around(_home);
        now = now.add(const Duration(hours: 25));
        await repository().around(_home);
        expect(shops.asked, hasLength(4));
      });
    });

    group('the tab', () {
      ProviderContainer container() {
        final c = ProviderContainer(
          overrides: [
            nowProvider.overrideWithValue(() => now),
            locationSourceProvider.overrideWithValue(phone),
            nearbyRepositoryProvider.overrideWithValue(repository()),
            shoppingListRepositoryProvider.overrideWithValue(
              ShoppingListRepository(
                cache: shoppingBox,
                remote: _Nothing(),
                outbox: () => throw StateError('no writes here'),
                newId: () => 'x',
                signedInUserId: () => 'u',
              ),
            ),
            pharmacyRepositoryProvider.overrideWithValue(
              PharmacyRepository(
                cache: pharmacyBox,
                remote: _Nothing(),
                outbox: () => throw StateError('no writes here'),
                newId: () => 'x',
                signedInUserId: () => 'u',
              ),
            ),
          ],
        );
        addTearDown(c.dispose);
        return c;
      }

      Future<ProviderContainer> opened() async {
        final c = container()..read(nearbyControllerProvider);
        // Let the open-time check run to the end.
        for (var i = 0; i < 5; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        return c;
      }

      test('opening never asks for permission, never takes a fix', () async {
        phone.accessIs = LocationAccess.denied;
        await opened();

        expect(phone.calls, <String>['access']);
        expect(shops.asked, isEmpty);
      });

      test("opening uses the phone's recent position, no new fix", () async {
        phone.last = (
          at: _home,
          takenAt: now.subtract(const Duration(minutes: 5)),
        );
        final c = await opened();

        expect(phone.calls, <String>['access', 'lastKnown']);
        expect(shops.asked, hasLength(2));
        final near = c
            .read(nearbyControllerProvider)
            .storesOf(StoreKind.supermarket);
        expect(near.single.store.name, 'كارفور');
      });

      test('a stale position is not "here"', () async {
        phone.last = (
          at: _home,
          takenAt: now.subtract(const Duration(hours: 2)),
        );
        await opened();

        expect(shops.asked, isEmpty);
      });

      test('a tap asks once, takes one fix, and looks around it', () async {
        phone.accessIs = LocationAccess.denied;
        final c = await opened();
        phone
          ..calls.clear()
          ..fresh = (at: _home, takenAt: now);

        await c.read(nearbyControllerProvider.notifier).locate();

        expect(phone.calls, <String>['access', 'request', 'current']);
        expect(shops.asked, hasLength(2));
      });

      test('"never ask again" is not asked; settings is offered', () async {
        phone.accessIs = LocationAccess.deniedForever;
        final c = await opened();
        final controller = c.read(nearbyControllerProvider.notifier);

        await controller.locate();
        await controller.openSettings();

        expect(phone.calls, isNot(contains('request')));
        expect(phone.calls, isNot(contains('current')));
        expect(phone.calls.last, 'settings');
      });

      test('no fix in time says so, and fetches nothing', () async {
        final c = await opened();

        await c.read(nearbyControllerProvider.notifier).locate();

        expect(c.read(nearbyControllerProvider).noFix, isTrue);
        expect(shops.asked, isEmpty);
      });

      test('the radius chips filter what is here, and fetch nothing', () async {
        phone.fresh = (at: _home, takenAt: now);
        final c = await opened();
        final controller = c.read(nearbyControllerProvider.notifier);
        await controller.locate();
        expect(shops.asked, hasLength(2));

        controller.setRadius(3000);
        final wide = c
            .read(nearbyControllerProvider)
            .storesOf(StoreKind.pharmacy);
        controller.setRadius(500);
        final narrow = c
            .read(nearbyControllerProvider)
            .storesOf(StoreKind.pharmacy);

        expect((wide.length, narrow.length), (2, 1));
        expect(shops.asked, hasLength(2));
      });

      test('a failed lookup keeps the last list and says so', () async {
        phone.fresh = (at: _home, takenAt: now);
        final c = await opened();
        final controller = c.read(nearbyControllerProvider.notifier);
        await controller.locate();

        shops.failWith = const SocketException('offline');
        phone.fresh = (at: const GeoPoint(30.10, 31.30), takenAt: now);
        await controller.locate();

        final view = c.read(nearbyControllerProvider);
        expect(view.error, isNotNull);
        expect(view.snapshot?.supermarkets, hasLength(2));
      });
    });
  });
}
