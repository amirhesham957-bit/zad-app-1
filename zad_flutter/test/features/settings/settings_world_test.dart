// The settings world: five groups, every control still reachable, the state
// line from real data, and the sounds switch still working.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/settings/presentation/settings_screen.dart';
import 'package:zad/shared/bank/application/bank_access_controller.dart';
import 'package:zad/shared/navigation/zad_slots.dart';
import 'package:zad/shared/quota/application/attempts_balance_provider.dart';
import 'package:zad/shared/settings/application/settings_controller.dart';
import 'package:zad/shared/settings/domain/account_settings.dart';

import '../../support/fonts.dart';
import '../../support/quiet_household.dart';

class _Settings extends SettingsController {
  new(this.settings);
  final AccountSettings? settings;
  @override
  SettingsView build() => SettingsView(settings: settings);
  @override
  Future<void> refresh({bool force = false}) async {}
}

class _Bank extends BankAccessController {
  @override
  BankAccessState build() => const BankAccessState(granted: false, pending: 0);
  @override
  Future<void> refresh() async {}
}

Widget _app(AccountSettings? settings) {
  ZadSlots.alertsSettingsSection = () => const Text('slot-alerts');
  ZadSlots.streetAlertsSection = () => const Text('slot-street');
  ZadSlots.keepAliveGuide = () => const Text('slot-keepalive');
  ZadSlots.signOutTile = () => const ListTile(title: Text('تسجيل الخروج'));
  return ProviderScope(
    overrides: <Override>[
      ...quietOrbOverrides,
      settingsControllerProvider.overrideWith(() => _Settings(settings)),
      bankAccessControllerProvider.overrideWith(_Bank.new),
      attemptsBalanceProvider.overrideWith((ref) async => null),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ZadTheme.light(),
      locale: const Locale('ar'),
      supportedLocales: ZadL10n.supportedLocales,
      localizationsDelegates: ZadL10n.localizationsDelegates,
      home: const SettingsScreen(),
    ),
  );
}

Future<void> _open(WidgetTester tester, Widget app, {double h = 4400}) async {
  tester.view
    ..physicalSize = Size(860, h)
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 400));
}

const AccountSettings _sa = AccountSettings(
  country: 'SA',
  currency: 'ر.س',
  monthlyLimit: 8000,
  cycleStartDay: 25,
);

void main() {
  testWidgets('five groups, every control, and a state line of real data', (
    tester,
  ) async {
    await _open(tester, _app(_sa));
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(find.text('السعودية · 8,000 ر.س'), findsOneWidget);
    for (final g in <String>[
      'الفلوس',
      'رفيق زاد',
      'الأصوات واللغة',
      'الإعلانات والخصوصية',
      'الحساب',
    ]) {
      expect(find.text(g), findsOneWidget, reason: g);
    }
    for (final r in <String>[
      'السقف الشهري',
      'يوم الراتب',
      'يوم 25 من كل شهر',
      'السماح بقراءة الإشعارات',
      'فعّلها خطوة بخطوة',
      'أصوات الواجهة',
      'الإعلانات',
      'الشروط والأحكام',
      'slot-alerts',
      'slot-street',
      'slot-keepalive',
      'تسجيل الخروج',
    ]) {
      expect(find.text(r), findsOneWidget, reason: r);
    }
    expect(find.byKey(const ValueKey<String>('pet-calls')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('food-pattern')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('app-language')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('nothing set yet says so instead of showing a zero', (
    tester,
  ) async {
    await _open(tester, _app(null));
    expect(find.text('لسه متحددش'), findsWidgets);
    expect(find.text('من أول الشهر (لسه مش متحدد)'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('screenshot: the settings world', (tester) async {
    await loadZadFonts();
    await _open(tester, _app(_sa), h: 3400);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../build/screens/world_settings.png'),
    );
    await tester.pumpWidget(const SizedBox());
  }, skip: Platform.environment['ZAD_SCREENS'] != '1');
}
