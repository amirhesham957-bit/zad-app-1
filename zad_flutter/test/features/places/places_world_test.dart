// «أماكني» as a world: its state line is real data, every list has an empty
// state, and the screenshot (ZAD_SCREENS=1) shows realistic rows.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/places/application/street_alerts_controller.dart';
import 'package:zad/features/places/domain/my_places.dart';
import 'package:zad/features/places/presentation/my_places_screen.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/zad_screens.dart';

import '../../support/fonts.dart';
import '../../support/quiet_household.dart';

class _Alerts extends StreetAlertsController {
  new(this.view);
  final StreetAlertsView view;

  @override
  StreetAlertsView build() => view;
}

Widget _app({
  required StreetAlertsStatus status,
  List<PlaceReminder> reminders = const <PlaceReminder>[],
  List<PlaceVisit> visits = const <PlaceVisit>[],
}) => ProviderScope(
  overrides: <Override>[
    ...quietHouseholdOverrides,
    accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
    streetAlertsControllerProvider.overrideWith(
      () => _Alerts(StreetAlertsView(status: status)),
    ),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ZadTheme.light(),
    locale: const Locale('ar'),
    supportedLocales: ZadL10n.supportedLocales,
    localizationsDelegates: ZadL10n.localizationsDelegates,
    // Reduced motion: the scene loop would never settle.
    builder: (c, child) => MediaQuery(
      data: MediaQuery.of(c).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: MyPlacesScreen(seedReminders: reminders, seedVisits: visits),
  ),
);

void _tall(WidgetTester tester, {double dpr = 1}) {
  tester.view
    ..physicalSize = Size(430 * dpr, 2400 * dpr)
    ..devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('ar');
  });
  tearDown(() => ZadScreens.worldScreen = (_) => null);

  testWidgets('empty account: state line, empty states and the add button', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(_app(status: StreetAlertsStatus.off));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('أماكني'), findsWidgets);
    expect(find.text('مفيش أماكن · تنبيهات الشارع مقفولة'), findsOneWidget);
    expect(find.text('مفيش خروجات متسجّلة'), findsOneWidget);
    expect(find.textContaining('فكّريني لما أروح'), findsOneWidget);
    expect(find.text('تذكير بمكان'), findsOneWidget);
  });

  testWidgets('with data: count and alerts-on in the state line', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(
      _app(
        status: StreetAlertsStatus.on,
        reminders: const <PlaceReminder>[
          (id: 'r1', note: 'بنادول', place: 'pharmacy'),
          (id: 'r2', note: 'لبن وعيش', place: 'supermarket'),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('مكانين · تنبيهات الشارع شغالة'), findsOneWidget);
    expect(find.text('بنادول'), findsOneWidget);
    expect(find.byTooltip('إلغاء التذكير'), findsNWidgets(2));
  });

  testWidgets('screenshot', (tester) async {
    await loadZadFonts();
    _tall(tester, dpr: 2);
    DateTime at(int d, int h) => DateTime.utc(2026, 11, d, h);
    PlaceVisit visit(int i, DateTime left, List<String> stores, double spent) =>
        (
          id: 'v$i',
          leftAt: left,
          returnedAt: left.add(const Duration(minutes: 75)),
          spent: spent,
          currency: 'EGP',
          merchants: const <String>[],
          stores: stores,
        );
    await tester.pumpWidget(
      _app(
        status: StreetAlertsStatus.on,
        reminders: const <PlaceReminder>[
          (id: 'r1', note: 'بنادول لماما', place: 'pharmacy'),
          (id: 'r2', note: 'لبن وعيش', place: 'supermarket'),
          (id: 'r3', note: 'شاحن للموبايل', place: 'mall'),
        ],
        visits: <PlaceVisit>[
          visit(1, at(5, 17), <String>['كارفور'], 340),
          visit(2, at(12, 17), <String>['كارفور', 'العزبي'], 120.5),
          visit(3, at(14, 12), <String>['العزبي'], 0),
          visit(4, at(19, 17), <String>['كارفور'], 410),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../build/screens/world_places.png'),
    );
  }, skip: Platform.environment['ZAD_SCREENS'] != '1');
}
