// P1.8: Home's rescue card. It shows only when something the customer relied
// on was taken away, and offers the fixes for it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/features/home/domain/rescue.dart';
import 'package:zad/features/home/presentation/rescue_card.dart';
import 'package:zad/shared/alerts/domain/push_alert.dart';
import 'package:zad/shared/bank/application/bank_access_controller.dart';
import 'package:zad/shared/nearby/data/location_source.dart';

final DateTime _now = DateTime.utc(2026, 11, 28, 12);

BankAccessState _bank({
  required bool granted,
  DateTime? connected,
  DateTime? seen,
  DateTime? captured,
}) => BankAccessState(
  granted: granted,
  pending: 0,
  lastConnectedAt: connected,
  lastCapturedAt: captured,
  lastSeenAnyAt: seen,
  checkedAt: _now,
);

final BankAccessState _flowing = _bank(
  granted: true,
  connected: _now.subtract(const Duration(days: 1)),
  captured: _now.subtract(const Duration(hours: 1)),
  seen: _now.subtract(const Duration(minutes: 5)),
);
final BankAccessState _stalled = _bank(
  granted: true,
  connected: _now.subtract(const Duration(days: 5)),
  captured: _now.subtract(const Duration(days: 4)),
  seen: _now.subtract(const Duration(hours: 13)),
);
final BankAccessState _tookAway = _bank(
  granted: false,
  connected: _now.subtract(const Duration(days: 3)),
);
final BankAccessState _neverOn = _bank(granted: false);

class _Bank extends BankAccessController {
  new(this.fixed);
  final BankAccessState fixed;
  int settingsOpened = 0;

  @override
  BankAccessState build() => fixed;
  @override
  Future<void> refresh() async {}
  @override
  Future<void> openSettings() async => settingsOpened++;
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

void main() {
  group('rescueCauses', () {
    test('healthy: nothing', () {
      expect(
        rescueCauses(
          bank: _flowing,
          location: LocationAccess.granted,
          locationNeeded: true,
        ),
        isEmpty,
      );
    });

    test('a stalled listener, and access taken back, are bank causes', () {
      for (final b in <BankAccessState>[_stalled, _tookAway]) {
        expect(
          rescueCauses(bank: b, location: null, locationNeeded: false),
          [RescueCause.bank],
        );
      }
    });

    test('never turned on: hidden', () {
      expect(
        rescueCauses(bank: _neverOn, location: null, locationNeeded: false),
        isEmpty,
      );
    });

    test('location lost counts only for an account that uses it', () {
      expect(
        rescueCauses(
          bank: _flowing,
          location: LocationAccess.denied,
          locationNeeded: true,
        ),
        [RescueCause.location],
      );
      expect(
        rescueCauses(
          bank: _flowing,
          location: LocationAccess.denied,
          locationNeeded: false,
        ),
        isEmpty,
      );
    });
  });

  test('autostart page only for the makers that have one', () {
    for (final m in <String>['Xiaomi', 'redmi', 'OPPO', 'vivo', 'HUAWEI']) {
      expect(hasAutostartPage(m), isTrue, reason: m);
    }
    for (final m in <String?>['samsung', 'google', '', null]) {
      expect(hasAutostartPage(m), isFalse, reason: '$m');
    }
  });

  test('the server route bank_fix opens the rescue destination', () {
    expect(destinationFor('bank_fix'), AlertDestination.rescue);
    expect(
      destinationFor(payloadFor(AlertDestination.rescue)),
      AlertDestination.rescue,
    );
    expect(
      PushAlert.fromMessage(
        data: const <String, dynamic>{'route': 'bank_fix'},
      ).destination,
      AlertDestination.rescue,
    );
  });

  group('RescueCard', () {
    late _Bank bank;
    late _Phone phone;
    late List<String> opened;

    Widget app({
      required BankAccessState state,
      LocationAccess location = LocationAccess.granted,
      bool locationNeeded = false,
      String? maker,
    }) {
      phone = _Phone(location);
      opened = <String>[];
      return ProviderScope(
        overrides: [
          bankAccessControllerProvider.overrideWith(() => bank = _Bank(state)),
          locationSourceProvider.overrideWithValue(phone),
          rescueLocationNeededProvider.overrideWithValue(
            () async => locationNeeded,
          ),
          phoneMakerProvider.overrideWithValue(() async => maker),
          autostartOpenerProvider.overrideWithValue(() async {
            opened.add('autostart');
            return true;
          }),
          batteryExemptionRequestProvider.overrideWithValue(() async {
            opened.add('battery');
            return false;
          }),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          locale: const Locale('ar'),
          supportedLocales: ZadL10n.supportedLocales,
          localizationsDelegates: ZadL10n.localizationsDelegates,
          home: const Scaffold(
            body: SingleChildScrollView(child: RescueCard()),
          ),
        ),
      );
    }

    Future<void> pumpApp(WidgetTester t, Widget w) async {
      t.view
        ..physicalSize = const Size(860, 1864)
        ..devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(w);
      await t.pumpAndSettle();
    }

    testWidgets('hidden when all is healthy', (t) async {
      await pumpApp(t, app(state: _flowing, locationNeeded: true));
      expect(find.byKey(const ValueKey<String>('rescue-card')), findsNothing);
    });

    testWidgets('hidden for a no-bank user who never enabled it', (t) async {
      await pumpApp(t, app(state: _neverOn));
      expect(find.byKey(const ValueKey<String>('rescue-card')), findsNothing);
    });

    testWidgets('stalled bank: listener and battery buttons work', (t) async {
      await pumpApp(t, app(state: _stalled, maker: 'samsung'));
      expect(find.byKey(const ValueKey<String>('rescue-card')), findsOneWidget);
      expect(find.text('التشغيل التلقائي'), findsNothing);

      await t.tap(find.text('الوصول للإشعارات'));
      await t.pumpAndSettle();
      expect(bank.settingsOpened, 1);

      await t.tap(find.text('قيود البطارية'));
      await t.pumpAndSettle();
      expect(opened, ['battery']);
    });

    testWidgets('Xiaomi shows the autostart button', (t) async {
      await pumpApp(t, app(state: _tookAway, maker: 'xiaomi'));
      await t.tap(find.text('التشغيل التلقائي'));
      await t.pumpAndSettle();
      expect(opened, ['autostart']);
    });

    testWidgets('location lost: one button asks again', (t) async {
      await pumpApp(
        t,
        app(
          state: _flowing,
          location: LocationAccess.denied,
          locationNeeded: true,
        ),
      );
      expect(find.text('الموقع اتقفل عن زاد'), findsOneWidget);
      expect(find.text('الوصول للإشعارات'), findsNothing);
      await t.tap(find.text('اسمح'));
      await t.pumpAndSettle();
      expect(phone.calls, ['request']);
    });
  });
}
