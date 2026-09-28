import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/features/nearby/domain/nearby.dart';
import 'package:zad/features/places/domain/places.dart';

void main() {
  setUpAll(tz_data.initializeTimeZones);

  const home = GeoPoint(30.0444, 31.2357);
  // ~500 m north.
  const elsewhere = GeoPoint(30.0489, 31.2357);

  group('learnHome', () {
    test('one night is not enough', () {
      expect(learnHome(<NightSample>[(at: home, date: '2026-09-01')]), isNull);
    });

    test('two nights at the same place is home', () {
      final learned = learnHome(<NightSample>[
        (at: home, date: '2026-09-01'),
        (at: const GeoPoint(30.0445, 31.2358), date: '2026-09-02'),
      ]);
      expect(learned, isNotNull);
      expect(learned!.metresTo(home), lessThan(20));
    });

    test('a night somewhere else does not pull home', () {
      final learned = learnHome(<NightSample>[
        (at: elsewhere, date: '2026-09-01'),
        (at: home, date: '2026-09-02'),
        (at: home, date: '2026-09-03'),
      ]);
      expect(learned!.metresTo(home), lessThan(5));
    });

    test('the latest night decides — a move is followed', () {
      expect(
        learnHome(<NightSample>[
          (at: home, date: '2026-09-01'),
          (at: home, date: '2026-09-02'),
          (at: elsewhere, date: '2026-09-03'),
        ]),
        isNull,
      );
    });
  });

  test('recordNight keeps one sample a date and reports a new home', () {
    var state = const PlaceState();
    final first = recordNight(state, home, '2026-09-01');
    expect(first.homeChanged, isFalse);
    state = recordNight(first.state, home, '2026-09-01').state;
    expect(state.nights, hasLength(1));
    final second = recordNight(state, home, '2026-09-02');
    expect(second.homeChanged, isTrue);
    expect(second.state.home, isNotNull);
    expect(recordNight(second.state, home, '2026-09-03').homeChanged, isFalse);
  });

  test('isOuting: 45 min to 18 h', () {
    final left = DateTime.utc(2026, 9, 1, 10);
    expect(isOuting(null, left), isFalse);
    expect(isOuting(left, left.add(const Duration(minutes: 44))), isFalse);
    expect(isOuting(left, left.add(const Duration(minutes: 45))), isTrue);
    expect(isOuting(left, left.add(const Duration(hours: 18))), isTrue);
    expect(isOuting(left, left.add(const Duration(hours: 19))), isFalse);
  });

  test('isNightHour is 01:00–04:59', () {
    expect(isNightHour(DateTime(2026, 9, 1, 0, 59)), isFalse);
    expect(isNightHour(DateTime(2026, 9, 1, 1)), isTrue);
    expect(isNightHour(DateTime(2026, 9, 1, 4, 59)), isTrue);
    expect(isNightHour(DateTime(2026, 9, 1, 5)), isFalse);
  });

  test('nextNightSample is the next 03:00 in the account zone', () {
    final cairo = tz.getLocation('Africa/Cairo');
    // 22:00 Cairo (UTC+3 in September) → 03:00 Cairo next day = 00:00 UTC.
    final evening = DateTime.utc(2026, 9, 1, 19);
    expect(nextNightSample(evening, cairo), DateTime.utc(2026, 9, 2));
    // 02:00 Cairo → 03:00 the same night.
    final early = DateTime.utc(2026, 9, 1, 23);
    expect(nextNightSample(early, cairo), DateTime.utc(2026, 9, 2));
  });

  group('planFences', () {
    NearbyStore shop(String name, double dLat, StoreKind kind) => NearbyStore(
      name: name,
      at: GeoPoint(home.lat + dLat, home.lon),
      kind: kind,
    );

    test('nearest shops per kind, home both ways, the area on exit only', () {
      final plan = planFences(
        shops: <NearbyStore>[
          shop('بعيد', 0.02, StoreKind.supermarket),
          shop('قريب', 0.001, StoreKind.supermarket),
          shop('صيدلية', 0.002, StoreKind.pharmacy),
          shop('برّه النطاق', 0.05, StoreKind.pharmacy),
        ],
        center: home,
        home: home,
      );
      expect(plan.shops['supermarket_0']?.name, 'قريب');
      expect(plan.shops['supermarket_1']?.name, 'بعيد');
      expect(plan.shops['pharmacy_0']?.name, 'صيدلية');
      expect(plan.shops, hasLength(3));
      final homeFence = plan.fences.singleWhere((f) => f.id == kHomeFence);
      expect(homeFence.enter && homeFence.exit, isTrue);
      final area = plan.fences.singleWhere((f) => f.id == kAreaFence);
      expect(area.enter, isFalse);
      expect(area.exit, isTrue);
    });

    test('no home yet, no home fence; never more than 15 shops a kind', () {
      final plan = planFences(
        shops: <NearbyStore>[
          for (var i = 0; i < 20; i++)
            shop('محل $i', i * 0.0005, StoreKind.supermarket),
        ],
        center: home,
      );
      expect(plan.fences.where((f) => f.id == kHomeFence), isEmpty);
      expect(plan.shops, hasLength(kShopsPerKind));
    });
  });

  test('the state survives its JSON', () {
    final state = PlaceState(
      enabled: true,
      zone: 'Africa/Cairo',
      shops: const <String, FencedShop>{
        'pharmacy_0': (name: 'العزبي', kind: StoreKind.pharmacy),
      },
      alerted: <String, DateTime>{'العزبي': DateTime.utc(2026, 9, 1, 12)},
      home: home,
      nights: const <NightSample>[(at: home, date: '2026-09-01')],
      leftAt: DateTime.utc(2026, 9, 1, 9),
      refreshedAt: DateTime.utc(2026, 9, 1, 8),
      center: elsewhere,
    );
    final back = PlaceState.fromJson(state.toJson());
    expect(back.enabled, isTrue);
    expect(back.zone, 'Africa/Cairo');
    expect(back.shops['pharmacy_0']?.kind, StoreKind.pharmacy);
    expect(back.alerted['العزبي'], DateTime.utc(2026, 9, 1, 12));
    expect(back.home?.lat, home.lat);
    expect(back.nights.single.date, '2026-09-01');
    expect(back.leftAt, DateTime.utc(2026, 9, 1, 9));
    expect(back.refreshedAt, DateTime.utc(2026, 9, 1, 8));
    expect(back.center?.lat, elsewhere.lat);
    expect(PlaceState.fromJson(const <String, dynamic>{}).enabled, isFalse);
  });
}
