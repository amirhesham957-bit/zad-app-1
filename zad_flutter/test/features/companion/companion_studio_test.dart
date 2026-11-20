import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/companion/presentation/companion_studio_screen.dart';
import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/campaigns/application/market_season.dart';
import 'package:zad/shared/companion/data/companion_remote.dart';
import 'package:zad/shared/companion/domain/companion_status.dart';
import 'package:zad/shared/kids/application/kids_mode_controller.dart';
import 'package:zad/shared/orb/application/orb_accessory_controller.dart';
import 'package:zad/shared/orb/domain/orb_accessory.dart';

import '../../shared/companion/companion_fakes.dart';
import '../../support/fonts.dart';

class _NoAccessory extends OrbAccessoryController {
  @override
  OrbAccessory build() => OrbAccessory.none;
}

Future<FakeCompanionRemote> _open(
  WidgetTester tester, {
  Map<String, dynamic>? json,
  bool kids = false,
  Size size = const Size(420, 2600),
  double dpr = 1,
}) async {
  final remote = FakeCompanionRemote(json ?? statusJson());
  tester.view
    ..physicalSize = size * dpr
    ..devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith(SignedIn.new),
        companionRemoteProvider.overrideWithValue(remote),
        orbAccessoryProvider.overrideWith(_NoAccessory.new),
        marketSeasonProvider.overrideWithValue(null),
        kidsModeActiveProvider.overrideWithValue(kids),
      ],
      child: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          theme: ZadTheme.light(),
          locale: const Locale('ar'),
          supportedLocales: ZadL10n.supportedLocales,
          localizationsDelegates: ZadL10n.localizationsDelegates,
          home: const CompanionStudioScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  return remote;
}

/// The orbs breathe forever, so nothing ever settles: step the clock.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  testWidgets('the state line, the level, the streak, the seeds, the tasks', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('رفيق زاد'), findsWidgets);
    expect(find.text('المستوى 2'), findsOneWidget);
    // One of three tasks is done: two are left.
    expect(find.text('فاضل 2 من مهام النهارده'), findsOneWidget);
    expect(find.text('لفل 2 · بذرة'), findsOneWidget);
    expect(find.text('30 / 140'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    expect(find.text('80'), findsWidgets);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('ZAD-7KQ4-M9TX'), findsOneWidget);
    expect(find.text('تحدي الأسبوع'), findsOneWidget);
    expect(find.text('سجّل مصروف في 5 أيام من ٧ — فاضلك 2.'), findsOneWidget);
    expect(find.text('مستعجل؟ اشحن بذور'), findsOneWidget);
    expect(find.text(r'أو $1.99'), findsWidgets);
    // The docked action, in the thumb zone.
    final dock = find.byKey(const ValueKey<String>('comp-pet'));
    expect(find.text('ربّت على زادو'), findsOneWidget);
    expect(tester.getSize(dock).height, greaterThanOrEqualTo(44));
    expect(tester.getCenter(dock).dy, greaterThan(2600 * 0.66));
  });

  testWidgets('patting wakes the companion and keeps the screen alive', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey<String>('comp-pet')));
    await tester.pump(const Duration(milliseconds: 1700));
    expect(tester.takeException(), isNull);
    expect(find.text('ربّت على زادو'), findsOneWidget);
  });

  testWidgets('the companion cannot be reached: an empty state with retry', (
    tester,
  ) async {
    final remote = FakeCompanionRemote(statusJson());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(SignedIn.new),
          companionRemoteProvider.overrideWithValue(_Down(remote)),
          orbAccessoryProvider.overrideWith(_NoAccessory.new),
          marketSeasonProvider.overrideWithValue(null),
          kidsModeActiveProvider.overrideWithValue(false),
        ],
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            theme: ZadTheme.light(),
            locale: const Locale('ar'),
            supportedLocales: ZadL10n.supportedLocales,
            localizationsDelegates: ZadL10n.localizationsDelegates,
            home: const CompanionStudioScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('الرفيق مش قادر يوصل'), findsOneWidget);
    expect(find.text('جرّب تاني'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('comp-pet')), findsNothing);
  });

  testWidgets('a character bought with seeds is worn at once', (tester) async {
    final remote = await _open(tester, json: statusJson(seeds: 5000));
    await tester.tap(find.byKey(const ValueKey<String>('buy-felfool')));
    await _settle(tester);
    await tester.tap(find.text('خده'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      remote.calls,
      containsAllInOrder(<String>['buy:felfool', 'status', 'equip:felfool']),
    );
  });

  testWidgets('not enough seeds says how many are missing', (tester) async {
    final remote = await _open(tester);
    remote.next = (ok: false, reason: 'not_enough', missing: 1920);
    await tester.tap(find.byKey(const ValueKey<String>('buy-felfool')));
    await _settle(tester);
    await tester.tap(find.text('خده'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('ناقصك 1920 بذرة'), findsOneWidget);
  });

  testWidgets('in kids mode nothing is for sale and there is no invite', (
    tester,
  ) async {
    await _open(tester, kids: true);
    expect(find.byKey(const ValueKey<String>('buy-felfool')), findsNothing);
    expect(find.text('ادعي صحابك'), findsNothing);
    expect(find.text('مستعجل؟ اشحن بذور'), findsNothing);
    expect(find.textContaining(r'$1.99'), findsNothing);
    expect(find.text('مقفول'), findsWidgets);
  });

  testWidgets("a friend's code goes to the server", (tester) async {
    final remote = await _open(tester);
    await tester.ensureVisible(find.text('عندك كود صاحبك؟ اكتبه هنا'));
    await tester.pump();
    await tester.tap(find.text('عندك كود صاحبك؟ اكتبه هنا'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'zad-aaaa-bbbb');
    await tester.tap(find.text('تأكيد'));
    await _settle(tester);
    expect(remote.calls, contains('claim:zad-aaaa-bbbb'));
  });

  testWidgets('owned and worn items say so', (tester) async {
    await _open(
      tester,
      json: statusJson(
        persona: 'felfool',
        owned: <String>['morning', 'zado', 'felfool'],
      ),
    );
    expect(find.text('لابسه'), findsOneWidget);
    expect(find.text('البسه'), findsOneWidget);
  });

  testWidgets('screenshot: the companion world', (tester) async {
    await loadZadFonts();
    await _open(
      tester,
      json: statusJson(seeds: 45, streak: 7, level: 7),
      size: const Size(430, 932),
      dpr: 2,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../build/screens/world_companion.png'),
    );
  }, skip: Platform.environment['ZAD_SCREENS'] != '1');
}

class _Down extends FakeCompanionRemote {
  new(FakeCompanionRemote o) : super(o.json);

  @override
  Future<CompanionStatus?> status() async => null;
}
