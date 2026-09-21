// What the "near you" tab says: before a fix, what a tap will do and that it
// is once; when location is closed for good, where to open it; with a list,
// the shops by distance, what the customer needs from them, and that these
// are distances, not prices.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/design/zad_theme.dart';
import 'package:zad/features/nearby/application/nearby_controller.dart';
import 'package:zad/features/nearby/data/location_source.dart';
import 'package:zad/features/nearby/data/nearby_repository.dart';
import 'package:zad/features/nearby/domain/nearby.dart';
import 'package:zad/features/nearby/presentation/nearby_view.dart';

class _Nearby extends NearbyController {
  new(this.initial);

  final NearbyView initial;
  final List<String> calls = <String>[];

  @override
  NearbyView build() => initial;

  @override
  Future<void> locate() async => calls.add('locate');

  @override
  Future<void> openSettings() async => calls.add('settings');

  @override
  void setRadius(int metres) => calls.add('radius:$metres');
}

const GeoPoint _here = GeoPoint(30.0444, 31.2357);

NearbySnapshot _snapshot() => NearbySnapshot(
  center: _here,
  fetchedAt: DateTime.utc(2026, 9, 21),
  supermarkets: const <NearbyStore>[
    NearbyStore(
      name: 'كارفور',
      at: GeoPoint(30.0470, 31.2357),
      kind: StoreKind.supermarket,
    ),
  ],
  pharmacies: const <NearbyStore>[],
);

void main() {
  late _Nearby nearby;

  Future<void> pump(WidgetTester tester, NearbyView view) async {
    nearby = _Nearby(view);
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [nearbyControllerProvider.overrideWith(() => nearby)],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: NearbyList()),
          ),
        ),
      ),
    );
  }

  testWidgets('before a fix: what a tap does, and that it is once', (
    tester,
  ) async {
    await pump(tester, const NearbyView(access: LocationAccess.denied));

    expect(find.text('نشوف إيه حواليك؟'), findsOneWidget);
    expect(find.textContaining('مرة واحدة'), findsOneWidget);
    expect(nearby.calls, isEmpty);

    await tester.tap(find.text('حدّد مكاني'));
    await tester.pump();
    expect(nearby.calls, <String>['locate']);
  });

  testWidgets('closed for good: where to open it', (tester) async {
    await pump(tester, const NearbyView(access: LocationAccess.deniedForever));

    expect(find.text('الموقع مقفول لزاد'), findsOneWidget);
    await tester.tap(find.text('افتح الإعدادات'));
    await tester.pump();
    expect(nearby.calls, <String>['settings']);
  });

  testWidgets('a list: by distance, what is needed, and what it is not', (
    tester,
  ) async {
    await pump(
      tester,
      NearbyView(
        snapshot: _snapshot(),
        here: _here,
        access: LocationAccess.granted,
        onList: const <String>['لبن', 'أرز'],
      ),
    );

    expect(find.text('كارفور'), findsOneWidget);
    expect(find.text('289 م'), findsOneWidget);
    expect(find.text('على قايمتك: لبن، أرز'), findsOneWidget);
    expect(find.textContaining('مفيش في نطاق 1.0 كم'), findsOneWidget);
    expect(find.textContaining('مش أسعار ولا عروض'), findsOneWidget);
    expect(find.text('حدّث مكاني'), findsOneWidget);

    await tester.tap(find.text('3.0 كم'));
    await tester.pump();
    expect(nearby.calls, <String>['radius:3000']);
  });
}
