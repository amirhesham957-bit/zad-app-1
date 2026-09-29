// «فكّرني لما أوصل»: the nearest shops become geofences, only with location
// allowed all the time, and they follow the customer only after a real move.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/local/boxes.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/nearby/application/nearby_controller.dart';
import 'package:zad/features/nearby/data/location_source.dart';
import 'package:zad/features/nearby/data/nearby_remote.dart';
import 'package:zad/features/nearby/data/nearby_repository.dart';
import 'package:zad/features/nearby/domain/nearby.dart';
import 'package:zad/features/place_alerts/application/place_alerts_controller.dart';
import 'package:zad/features/place_alerts/data/fence_platform.dart';
import 'package:zad/features/place_alerts/data/place_arrival_background.dart';
import 'package:zad/features/place_alerts/domain/place_fences.dart';

const _home = GeoPoint(30.0444, 31.2357);

NearbyStore _shop(String name, double dLat, StoreKind kind) => NearbyStore(
  name: name,
  at: GeoPoint(_home.lat + dLat, _home.lon),
  kind: kind,
);

class _Fences implements FencePlatform {
  List<FenceSpec>? registered;
  int clears = 0;

  @override
  Future<void> replaceAll(List<FenceSpec> fences) async => registered = fences;

  @override
  Future<void> clear() async {
    clears++;
    registered = null;
  }
}

class _Permissions implements FencePermissions {
  new({this.foregroundOk = true, this.alwaysOk = true});

  bool foregroundOk;
  bool alwaysOk;

  @override
  Future<bool> foreground() async => foregroundOk;

  @override
  Future<bool> always() async => alwaysOk;

  @override
  Future<bool> hasAlways() async => alwaysOk;
}

class _Location implements LocationSource {
  GeoPoint at = _home;

  @override
  Future<Fix?> current() async => (at: at, takenAt: DateTime.utc(2026, 9, 29));

  @override
  Future<Fix?> lastKnown() => current();

  @override
  Future<LocationAccess> access() async => LocationAccess.granted;

  @override
  Future<LocationAccess> request() async => LocationAccess.granted;

  @override
  Future<void> openSettings() async {}

  @override
  Future<void> openLocationSettings() async {}
}

class _Shops implements NearbyRemote {
  int calls = 0;

  @override
  Future<List<NearbyStore>> stores({
    required GeoPoint at,
    required StoreKind kind,
    required int radius,
  }) async {
    calls++;
    return kind == StoreKind.pharmacy
        ? <NearbyStore>[_shop('صيدلية العزبي', 0.002, kind)]
        : <NearbyStore>[
            _shop('كارفور', 0.01, kind),
            _shop('بقالة أم محمد', 0.001, kind),
          ];
  }
}

void main() {
  group('which shops, and what a fence id carries', () {
    test('nearest first, capped, and each id names its shop', () {
      final many = <NearbyStore>[
        for (var i = 0; i < 30; i++)
          _shop('محل $i', 0.001 * (30 - i), StoreKind.supermarket),
      ];
      final fences = pickFences(many, _home);
      expect(fences, hasLength(kMaxFences));
      expect(fences.first.name, 'محل 29');
      expect(fences.map((f) => f.id).toSet(), hasLength(kMaxFences));
      expect(fenceStore(fences.first.id), (
        kind: StoreKind.supermarket,
        name: 'محل 29',
      ));
    });

    test('a name with the separator in it survives, a foreign id does not', () {
      final id = fenceId(StoreKind.pharmacy, 'صيدلية | الشفا', 0);
      expect(fenceStore(id)?.name, 'صيدلية الشفا');
      expect(fenceStore('someone-else'), isNull);
    });

    test('drawn again only after a real move', () {
      expect(fencesStale(null, _home), isTrue);
      expect(fencesStale(_home, const GeoPoint(30.0454, 31.2357)), isFalse);
      expect(fencesStale(_home, const GeoPoint(30.0644, 31.2357)), isTrue);
    });

    test('an arrival asks the server with the shop, not the place', () {
      expect(storeArrivalBody('pharmacy', 'صيدلية العزبي'), <String, dynamic>{
        'action': 'store_arrival',
        'category': 'pharmacy',
        'store_name': 'صيدلية العزبي',
      });
    });
  });

  group('turning it on and off', () {
    late Directory dir;
    late Box<String> box;
    late _Fences fences;
    late _Permissions permissions;
    late _Location location;
    late _Shops shops;
    late ProviderContainer container;
    var run = 0;

    Future<void> build({bool foreground = true, bool always = true}) async {
      run++;
      dir = await Directory.systemTemp.createTemp('zad_place_alerts');
      Hive.init(dir.path);
      box = await Hive.openBox<String>('b$run');
      fences = _Fences();
      permissions = _Permissions(foregroundOk: foreground, alwaysOk: always);
      location = _Location();
      shops = _Shops();
      final store = ZadLocalStore(
        outbox: box,
        transactions: box,
        documents: box,
        chat: box,
        inventory: box,
        shopping: box,
        pharmacy: box,
        subscriptions: box,
        device: box,
      );
      container = ProviderContainer(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          fencePlatformProvider.overrideWithValue(fences),
          fencePermissionsProvider.overrideWithValue(permissions),
          locationSourceProvider.overrideWithValue(location),
          nearbyRepositoryProvider.overrideWithValue(
            NearbyRepository(
              cache: box,
              remote: shops,
              now: () => DateTime.utc(2026, 9, 29),
            ),
          ),
        ],
      );
    }

    tearDown(() async {
      container.dispose();
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });

    PlaceAlertsController controller() =>
        container.read(placeAlertsControllerProvider.notifier);

    test('on: the three shops around are watched, nearest first', () async {
      await build();
      await controller().enable();
      final view = container.read(placeAlertsControllerProvider);
      expect(view.enabled, isTrue);
      expect(view.watching, 3);
      expect(view.problem, isNull);
      expect(fences.registered!.map((f) => f.name), <String>[
        'بقالة أم محمد',
        'صيدلية العزبي',
        'كارفور',
      ]);
    });

    test('no «all the time»: nothing is watched and it says why', () async {
      await build(always: false);
      await controller().enable();
      final view = container.read(placeAlertsControllerProvider);
      expect(view.enabled, isFalse);
      expect(view.problem, contains('السماح طول الوقت'));
      expect(fences.registered, isNull);
    });

    test('a small move keeps the fences; a real one redraws them', () async {
      await build();
      await controller().enable();
      final first = shops.calls;

      location.at = const GeoPoint(30.0454, 31.2357);
      await controller().refresh();
      expect(shops.calls, first);

      location.at = const GeoPoint(30.0744, 31.2357);
      await controller().refresh();
      expect(shops.calls, greaterThan(first));
    });

    test('off: every fence is removed', () async {
      await build();
      await controller().enable();
      await controller().disable();
      expect(fences.clears, 1);
      expect(container.read(placeAlertsControllerProvider).enabled, isFalse);
    });
  });
}
