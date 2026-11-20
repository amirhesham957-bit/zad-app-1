// Turning street alerts on takes one fix and registers fences round it. The
// OS's last fix stands in only while it is recent: an old one would put the
// fences round the wrong place.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/features/places/application/street_alerts_controller.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/nearby/data/location_source.dart';
import 'package:zad/shared/nearby/domain/nearby.dart';
import 'package:zad/shared/places/application/place_engine.dart';
import 'package:zad/shared/places/data/background_location.dart';
import 'package:zad/shared/places/domain/places.dart';

class _Engine implements PlaceEngine {
  final List<GeoPoint> enabledAt = <GeoPoint>[];

  @override
  Future<void> enable({required GeoPoint at, required String zone}) async =>
      enabledAt.add(at);

  @override
  Future<PlaceState> state() async => const PlaceState();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _Phone implements LocationSource {
  Fix? last;
  Fix? fresh;

  @override
  Future<LocationAccess> access() async => LocationAccess.granted;
  @override
  Future<LocationAccess> request() async => LocationAccess.granted;
  @override
  Future<Fix?> lastKnown() async => last;
  @override
  Future<Fix?> current() async => fresh;
  @override
  Future<void> openSettings() async {}
  @override
  Future<void> openLocationSettings() async {}
}

class _Always implements BackgroundLocationAccess {
  @override
  Future<bool> granted() async => true;
  @override
  Future<bool> request() async => true;
  @override
  Future<void> openSettings() async {}
}

void main() {
  const spot = GeoPoint(30.0444, 31.2357);
  final now = DateTime.utc(2026, 11, 20, 12);
  late _Engine engine;
  late _Phone phone;
  late ProviderContainer c;

  setUp(() {
    engine = _Engine();
    phone = _Phone();
    c = ProviderContainer(
      overrides: [
        placeEngineProvider.overrideWithValue(engine),
        locationSourceProvider.overrideWithValue(phone),
        backgroundLocationProvider.overrideWithValue(_Always()),
        nowProvider.overrideWithValue(() => now),
        accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
      ],
    );
    addTearDown(c.dispose);
  });

  test('a recent last fix stands in when no new fix comes', () async {
    phone.last = (at: spot, takenAt: now.subtract(const Duration(minutes: 5)));
    await c.read(streetAlertsControllerProvider.notifier).turnOn();
    expect(engine.enabledAt, <GeoPoint>[spot]);
  });

  test('an old last fix is no fix: nothing registered, noFix said', () async {
    phone.last = (at: spot, takenAt: now.subtract(const Duration(hours: 3)));
    await c.read(streetAlertsControllerProvider.notifier).turnOn();
    expect(engine.enabledAt, isEmpty);
    expect(
      c.read(streetAlertsControllerProvider).status,
      StreetAlertsStatus.noFix,
    );
  });

  test('a new fix is used however old the last one is', () async {
    phone
      ..fresh = (at: spot, takenAt: now)
      ..last = (
        at: const GeoPoint(1, 1),
        takenAt: now.subtract(const Duration(days: 2)),
      );
    await c.read(streetAlertsControllerProvider.notifier).turnOn();
    expect(engine.enabledAt, <GeoPoint>[spot]);
  });
}
