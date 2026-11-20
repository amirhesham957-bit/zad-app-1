// «إنجازاتي» as a world: the state line reads "N من M إنجاز", an earned badge
// shows its date, a locked one «مقفول», and the level card stays.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/achievements/domain/achievements.dart';
import 'package:zad/features/achievements/presentation/achievements_screen.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';

import '../../support/fonts.dart';
import '../../support/quiet_household.dart';

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('ar');
  });

  Future<void> pump(
    WidgetTester tester,
    Future<(AchievementStats, List<AchievementView>)> Function() load, {
    Size size = const Size(430, 3000),
    double dpr = 1,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...quietOrbOverrides,
          accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
        ],
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            theme: ZadTheme.light(),
            locale: const Locale('ar'),
            supportedLocales: ZadL10n.supportedLocales,
            localizationsDelegates: ZadL10n.localizationsDelegates,
            home: AchievementsScreen(loadForTest: load),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  (AchievementStats, List<AchievementView>) sample() => buildAchievements(
    unlocked: const <UnlockedRow>[
      (achievementId: 'first_step', points: 10),
      (achievementId: 'rising_star', points: 50),
    ],
    unlockedAt: <String, DateTime>{
      'first_step': DateTime.utc(2026, 11, 3, 10),
      'rising_star': DateTime.utc(2026, 11, 12, 18),
    },
    contributions: 12,
    streak: 1,
  );

  testWidgets('the state line, the level, the date and the locked ones', (
    tester,
  ) async {
    await pump(tester, () async => sample());
    expect(find.text('إنجازاتي'), findsWidgets);
    expect(find.text('2 من 6 إنجاز'), findsOneWidget);
    expect(find.text('المستوى 1'), findsOneWidget);
    expect(find.textContaining('نوفمبر'), findsNWidgets(2));
    expect(find.text('مقفول'), findsNWidgets(4));
    expect(find.text('الإنجاز التالي · 12/50 مساهمة'), findsNothing);
    expect(find.textContaining('الإنجاز التالي'), findsOneWidget);
  });

  testWidgets('a new account: nothing earned, every badge locked', (
    tester,
  ) async {
    await pump(
      tester,
      () async => buildAchievements(
        unlocked: const <UnlockedRow>[],
        contributions: 0,
        streak: 0,
      ),
    );
    expect(find.text('0 من 6 إنجاز'), findsOneWidget);
    expect(find.text('مقفول'), findsNWidgets(6));
  });

  testWidgets('a failed read offers a retry', (tester) async {
    var calls = 0;
    await pump(tester, () async {
      calls++;
      if (calls == 1) throw Exception('offline');
      return sample();
    });
    expect(find.text('جرّب تاني'), findsOneWidget);
    await tester.tap(find.text('جرّب تاني'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('2 من 6 إنجاز'), findsOneWidget);
  });

  testWidgets('screenshot: the achievements world', (tester) async {
    await loadZadFonts();
    await pump(
      tester,
      () async => sample(),
      size: const Size(860, 1864),
      dpr: 2,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../build/screens/world_ach.png'),
    );
  }, skip: Platform.environment['ZAD_SCREENS'] != '1');
}
