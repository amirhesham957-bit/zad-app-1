import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/companion/presentation/companion_studio_screen.dart';
import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/campaigns/application/market_season.dart';
import 'package:zad/shared/companion/data/companion_remote.dart';
import 'package:zad/shared/kids/application/kids_mode_controller.dart';
import 'package:zad/shared/orb/application/orb_accessory_controller.dart';
import 'package:zad/shared/orb/domain/orb_accessory.dart';

import '../../shared/companion/companion_fakes.dart';

class _NoAccessory extends OrbAccessoryController {
  @override
  OrbAccessory build() => OrbAccessory.none;
}

Future<FakeCompanionRemote> _open(
  WidgetTester tester, {
  Map<String, dynamic>? json,
  bool kids = false,
}) async {
  final remote = FakeCompanionRemote(json ?? statusJson());
  await tester.binding.setSurfaceSize(const Size(420, 2600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith(SignedIn.new),
        companionRemoteProvider.overrideWithValue(remote),
        orbAccessoryProvider.overrideWith(_NoAccessory.new),
        marketSeasonProvider.overrideWithValue(null),
        kidsModeActiveProvider.overrideWithValue(kids),
      ],
      child: const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: CompanionStudioScreen(),
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
  testWidgets('the level, the stage, the streak, the seeds and the missions', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('لفل 2'), findsOneWidget);
    expect(find.text('· بذرة'), findsOneWidget);
    expect(find.text('30 / 140 ⭐'), findsOneWidget);
    expect(find.text('🔥 3'), findsOneWidget);
    expect(find.text('🌱 80'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('ZAD-7KQ4-M9TX'), findsOneWidget);
    expect(find.text('تحدي الأسبوع'), findsOneWidget);
    expect(find.text('سجّل مصروف في 5 أيام من ٧ — فاضلك 2.'), findsOneWidget);
    expect(find.text('مستعجل؟ اشحن بذور'), findsOneWidget);
    expect(find.text(r'أو $1.99'), findsWidgets);
  });

  testWidgets('a character bought with seeds is worn at once', (tester) async {
    final remote = await _open(tester, json: statusJson(seeds: 5000));
    await tester.tap(find.text('2000 🌱').first);
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
    await tester.tap(find.text('2000 🌱').first);
    await _settle(tester);
    await tester.tap(find.text('خده'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('ناقصك 1920 🌱'), findsOneWidget);
  });

  testWidgets('in kids mode nothing is for sale and there is no invite', (
    tester,
  ) async {
    await _open(tester, kids: true);
    expect(find.text('2000 🌱'), findsNothing);
    expect(find.text('ادعي صحابك'), findsNothing);
    expect(find.text('مستعجل؟ اشحن بذور'), findsNothing);
    expect(find.textContaining(r'$1.99'), findsNothing);
    expect(find.text('🔒'), findsWidgets);
  });

  testWidgets("a friend's code goes to the server", (tester) async {
    final remote = await _open(tester);
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
    expect(find.text('لابسه ✓'), findsOneWidget);
    expect(find.text('البسه'), findsOneWidget);
  });
}
