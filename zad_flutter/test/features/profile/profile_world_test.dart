// The profile world: the state line (name · market · plan) from real data,
// the four groups with every row still reachable, a new account's state line
// with only a name, and sign-out / delete-account keeping their questions.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/profile/presentation/profile_screen.dart';
import 'package:zad/shared/family/application/family_controller.dart';
import 'package:zad/shared/kids/application/kids_mode_controller.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/profile/application/profile_controller.dart';
import 'package:zad/shared/quota/application/attempts_balance_provider.dart';
import 'package:zad/shared/quota/domain/attempts_balance.dart';
import 'package:zad/shared/settings/application/settings_controller.dart';
import 'package:zad/shared/settings/domain/account_settings.dart';

import '../../support/fonts.dart';
import '../../support/quiet_household.dart';

class _Kids extends KidsModeController {
  @override
  KidsModeState build() => (manual: false, pinUnlocked: false);
}

class _Profile extends ProfileController {
  new(this.view);
  final ProfileView view;
  @override
  ProfileView build() => view;
  @override
  Future<void> refresh() async {}
}

class _Settings extends SettingsController {
  new(this.country);
  final String? country;
  @override
  SettingsView build() => SettingsView(
    settings: country == null ? null : AccountSettings(country: country),
  );
  @override
  Future<void> refresh({bool force = false}) async {}
}

Widget _app({required ProfileView view, String? country, String? tier}) =>
    ProviderScope(
      overrides: <Override>[
        ...quietOrbOverrides,
        kidsModeProvider.overrideWith(_Kids.new),
        familyControllerProvider.overrideWith(QuietFamily.new),
        profileControllerProvider.overrideWith(() => _Profile(view)),
        settingsControllerProvider.overrideWith(() => _Settings(country)),
        attemptsBalanceProvider.overrideWith(
          (ref) async => tier == null
              ? null
              : AttemptsBalance(
                  tier: tier,
                  left: 120,
                  perCycle: 300,
                  nextRefillAt: null,
                  adsEnabled: false,
                ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ZadTheme.light(),
        locale: const Locale('ar'),
        supportedLocales: ZadL10n.supportedLocales,
        localizationsDelegates: ZadL10n.localizationsDelegates,
        home: const ProfileScreen(),
      ),
    );

Future<void> _open(WidgetTester tester, Widget app, {double h = 6000}) async {
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

void main() {
  testWidgets('the state line is name · market · plan, in four groups', (
    tester,
  ) async {
    await _open(
      tester,
      _app(
        view: const ProfileView(name: 'محمد', shortId: 'AB12CD34'),
        country: 'SA',
        tier: 'plus',
      ),
    );
    expect(find.text('حسابي'), findsOneWidget);
    expect(find.text('محمد · السعودية · المتقدمة'), findsOneWidget);
    for (final g in <String>[
      'أنا وزاد',
      'الحساب والعيلة',
      'الفلوس',
      'رفيق زاد والاشتراك',
    ]) {
      expect(find.text(g), findsOneWidget);
    }
    // Every row that was reachable before still is.
    for (final r in <String>[
      'زاد عارف عني إيه',
      'سجل تعديلات زاد',
      'تنبيهات المساعد الذكي',
      'هدف حياة جديد',
      'تعديل الملف الشخصي',
      'إدارة العائلة',
      'الإعدادات الإقليمية',
      'الميزانية وطرق الدفع',
      'استيراد كشف حساب',
      'الدعم الفني',
      'الشروط والأحكام',
      'حذف الحساب',
      'الإنجازات والرتب',
      'تسجيل الخروج',
    ]) {
      expect(find.text(r), findsOneWidget, reason: r);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a new account with nothing known shows just the name', (
    tester,
  ) async {
    await _open(tester, _app(view: const ProfileView()));
    expect(find.text('مستخدم جديد'), findsWidgets);
    expect(find.textContaining('·'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'delete account still asks first; sign-out goes through its door',
    (tester) async {
      var signOut = 0;
      ZadScreens.confirmAndSignOut = (_, _) async => signOut++;
      await _open(tester, _app(view: const ProfileView(name: 'محمد')));
      await tester.ensureVisible(find.text('حذف الحساب'));
      await tester.tap(find.text('حذف الحساب'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('نعم، احذف الحساب'), findsOneWidget);
      await tester.tap(find.text('إلغاء'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('تسجيل الخروج'));
      await tester.tap(find.text('تسجيل الخروج'));
      expect(signOut, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('screenshot: the profile world', (tester) async {
    await loadZadFonts();
    await _open(
      tester,
      _app(
        view: const ProfileView(name: 'محمد', shortId: 'AB12CD34'),
        country: 'SA',
        tier: 'plus',
      ),
      h: 1864,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../build/screens/world_profile.png'),
    );
    await tester.pumpWidget(const SizedBox());
  }, skip: Platform.environment['ZAD_SCREENS'] != '1');
}
