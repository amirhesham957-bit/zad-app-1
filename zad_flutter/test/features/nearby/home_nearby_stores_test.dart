import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/nearby/data/nearby_repository.dart';
import 'package:zad/features/nearby/presentation/home_nearby_stores.dart';
import 'package:zad/shared/nearby/domain/nearby.dart';

void main() {
  const center = GeoPoint(30.0444, 31.2357);
  // About 111 m per 0.001° of latitude.
  NearbyStore at(String name, double north, StoreKind kind) => NearbyStore(
    name: name,
    at: GeoPoint(30.0444 + north, 31.2357),
    kind: kind,
  );

  NearbySnapshot snapshot({
    List<NearbyStore> supermarkets = const <NearbyStore>[],
    List<NearbyStore> pharmacies = const <NearbyStore>[],
  }) => NearbySnapshot(
    center: center,
    fetchedAt: DateTime.utc(2026, 11, 11),
    supermarkets: supermarkets,
    pharmacies: pharmacies,
  );

  test('nothing kept, nothing shown — Home never asks for a fix', () {
    expect(homeNearbyStores(null), isEmpty);
  });

  test('both kinds in one row, nearest first, each name once', () {
    final stores = homeNearbyStores(
      snapshot(
        supermarkets: <NearbyStore>[
          at('كارفور', 0.010, StoreKind.supermarket), // l10n: data
          at('خير زمان', 0.002, StoreKind.supermarket), // l10n: data
          at('كارفور', 0.011, StoreKind.supermarket), // l10n: data
        ],
        pharmacies: <NearbyStore>[
          at('العزبي', 0.005, StoreKind.pharmacy), // l10n: data
        ],
      ),
    );
    expect(
      <String>[for (final s in stores) s.store.name],
      <String>['خير زمان', 'العزبي', 'كارفور'], // l10n: data
    );
  });

  test('past the widest radius stays out, and the row stops at ten', () {
    final stores = homeNearbyStores(
      snapshot(
        supermarkets: <NearbyStore>[
          for (var i = 0; i < 14; i++)
            at('محل $i', 0.001 * (i + 1), StoreKind.supermarket), // l10n: data
          at('بعيد', 0.05, StoreKind.supermarket), // l10n: data
        ],
      ),
    );
    expect(stores, hasLength(homeNearbyShown));
    expect(
      stores.every((s) => s.metres <= NearbyRepository.fetchRadius),
      isTrue,
    );
  });
}
