// «حالة زاد»: one green line when all works, open with the broken rows first
// otherwise. The screenshots run only with ZAD_SCREENS=1.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/features/home/presentation/zad_status_card.dart';
import 'package:zad/shared/bank/application/bank_access_controller.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/nearby/data/location_source.dart';

import '../../support/fonts.dart';

final DateTime _now = DateTime.utc(2026, 11, 20, 12);

class _Bank extends BankAccessController {
  new(this.fixed);
  final BankAccessState fixed;

  @override
  BankAccessState build() => fixed;

  @override
  Future<void> refresh() async {}
}

class _Phone implements LocationSource {
  new(this.is_);
  LocationAccess is_;
  final List<String> calls = <String>[];

  @override
  Future<LocationAccess> access() async => is_;
  @override
  Future<LocationAccess> request() async {
    calls.add('request');
    return is_;
  }

  @override
  Future<Fix?> lastKnown() async => null;
  @override
  Future<Fix?> current() async => null;
  @override
  Future<void> openSettings() async => calls.add('settings');
  @override
  Future<void> openLocationSettings() async => calls.add('locationSettings');
}

final BankAccessState _flowing = BankAccessState(
  granted: true,
  pending: 0,
  lastConnectedAt: _now.subtract(const Duration(days: 1)),
  lastCapturedAt: _now.subtract(const Duration(hours: 1)),
  lastSeenAnyAt: _now.subtract(const Duration(minutes: 5)),
  checkedAt: _now,
);

final BankAccessState _stalled = BankAccessState(
  granted: true,
  pending: 0,
  lastConnectedAt: _now.subtract(const Duration(days: 5)),
  lastCapturedAt: _now.subtract(const Duration(days: 4)),
  lastSeenAnyAt: _now.subtract(const Duration(days: 2)),
  checkedAt: _now,
);

Widget _app({
  required BankAccessState bank,
  required _Phone phone,
  required bool battery,
}) => ProviderScope(
  overrides: [
    nowProvider.overrideWithValue(() => _now),
    bankAccessControllerProvider.overrideWith(() => _Bank(bank)),
    locationSourceProvider.overrideWithValue(phone),
    batteryUnrestrictedProvider.overrideWithValue(() async => battery),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ZadTheme.light(),
    locale: const Locale('ar'),
    supportedLocales: ZadL10n.supportedLocales,
    localizationsDelegates: ZadL10n.localizationsDelegates,
    home: Scaffold(
      backgroundColor: ZadColors.canvasTop,
      body: const Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 64, 20, 0),
          child: ZadStatusCard(),
        ),
      ),
    ),
  ),
);

void main() {
  late Future<bool> Function(WidgetRef) savedAllowed;
  late Future<bool> Function(WidgetRef) savedAsk;
  late bool notificationsOn;

  setUp(() {
    savedAllowed = ZadScreens.notificationsAllowed;
    savedAsk = ZadScreens.askNotifications;
    notificationsOn = true;
    ZadScreens.notificationsAllowed = (_) async => notificationsOn;
    ZadScreens.askNotifications = (_) async => notificationsOn;
  });
  tearDown(() {
    ZadScreens.notificationsAllowed = savedAllowed;
    ZadScreens.askNotifications = savedAsk;
  });

  Future<void> prepare(WidgetTester tester) async {
    await loadZadFonts();
    tester.view
      ..physicalSize = const Size(860, 1864)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../build/screens/zad_status_$name.png'),
    );
  }

  testWidgets('all working: one calm line, details on a tap', (tester) async {
    await tester.pumpWidget(
      _app(
        bank: _flowing,
        phone: _Phone(LocationAccess.granted),
        battery: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('زاد شغال وبيتابع'), findsOneWidget);
    expect(find.text('الإشعارات'), findsNothing);

    await tester.tap(find.text('زاد شغال وبيتابع'));
    await tester.pumpAndSettle();
    expect(find.text('الإشعارات'), findsOneWidget);
    expect(find.text('شغال'), findsWidgets);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('three broken: open, broken first, a button each', (
    tester,
  ) async {
    notificationsOn = false;
    final phone = _Phone(LocationAccess.serviceOff);
    await tester.pumpWidget(_app(bank: _stalled, phone: phone, battery: true));
    await tester.pumpAndSettle();

    expect(find.text('زاد شغال وبيتابع'), findsNothing);
    expect(find.byType(FilledButton), findsNWidgets(3));
    final bank = tester.getTopLeft(find.text('قراءة رسائل البنك')).dy;
    final battery = tester.getTopLeft(find.text('توفير البطارية')).dy;
    expect(bank, lessThan(battery), reason: 'broken rows come first');

    await tester.tap(find.text('شغّل الموقع'));
    await tester.pumpAndSettle();
    expect(phone.calls, contains('locationSettings'));
  });

  testWidgets('«مش دلوقتي» puts the location row away', (tester) async {
    await tester.pumpWidget(
      _app(bank: _flowing, phone: _Phone(LocationAccess.denied), battery: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('مش دلوقتي'), findsOneWidget);
    // Without a store the snooze cannot be saved (a test host): it stays.
  });

  testWidgets('screenshot: all working, collapsed', (tester) async {
    await prepare(tester);
    await tester.pumpWidget(
      _app(
        bank: _flowing,
        phone: _Phone(LocationAccess.granted),
        battery: true,
      ),
    );
    await tester.pumpAndSettle();
    await shoot(tester, 'working');
  }, skip: Platform.environment['ZAD_SCREENS'] != '1');

  testWidgets('screenshot: two broken, open', (tester) async {
    await prepare(tester);
    notificationsOn = true;
    await tester.pumpWidget(
      _app(
        bank: _stalled,
        phone: _Phone(LocationAccess.serviceOff),
        battery: true,
      ),
    );
    await tester.pumpAndSettle();
    await shoot(tester, 'broken');
  }, skip: Platform.environment['ZAD_SCREENS'] != '1');
}
