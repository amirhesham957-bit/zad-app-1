// ZadWorldScaffold: the one identity every world shares, its links through
// the ZadScreens contract, the customer's own companion, and the pantry as
// the reference world.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/inventory/presentation/pantry_view.dart';
import 'package:zad/shared/companion/application/companion_controller.dart';
import 'package:zad/shared/companion/domain/companion_catalog.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart'
    as pantry;
import 'package:zad/shared/inventory/application/shopping_controller.dart';
import 'package:zad/shared/inventory/domain/inventory_item.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';
import 'package:zad/shared/worlds/world_scaffold.dart';
import 'package:zad/shared/worlds/zad_world.dart';

import '../../support/fonts.dart';
import '../../support/quiet_household.dart';

class _Quiet extends CustomPainter {
  new(this.loop) : super(repaint: loop);
  final Animation<double> loop;
  @override
  void paint(Canvas canvas, Size size) {}
  @override
  bool shouldRepaint(_Quiet old) => false;
}

Widget _app(Widget home, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: [...quietOrbOverrides, ...overrides],
      child: MaterialApp(
        theme: ZadTheme.light(),
        locale: const Locale('ar'),
        supportedLocales: ZadL10n.supportedLocales,
        localizationsDelegates: ZadL10n.localizationsDelegates,
        home: home,
      ),
    );

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('ar');
  });
  tearDown(() => ZadScreens.worldScreen = (_) => null);

  Widget world() => Builder(
    builder: (context) => ZadWorldScaffold(
      world: ZadWorld.inv,
      eyebrow: 'EYEBROW',
      title: 'TITLE',
      stateLine: 'STATE',
      scene: (loop) {
        _lastLoop = loop;
        return _Quiet(loop);
      },
      slivers: const <Widget>[SliverToBoxAdapter(child: Text('BODY'))],
    ),
  );

  testWidgets('title, eyebrow, state, body and a back button render', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () => Navigator.of(c).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(body: world()),
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    for (final t in <String>['EYEBROW', 'TITLE', 'STATE', 'BODY']) {
      expect(find.text(t), findsOneWidget);
    }
    expect(find.byTooltip('رجوع'), findsOneWidget);
    await tester.tap(find.byTooltip('رجوع'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('TITLE'), findsNothing);
  });

  testWidgets('a link opens through ZadScreens; a world with no screen has '
      'no chip', (tester) async {
    var opened = 0;
    tester.view
      ..physicalSize = const Size(800, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ZadScreens.worldScreen = (w) =>
        w == ZadWorld.chef ? (_) async => opened++ : null;
    await tester.pumpWidget(_app(Scaffold(body: world())));
    await tester.pump();
    expect(find.text('متصلة بـ'), findsNothing, reason: 'rich text');
    expect(find.text('التسوق'), findsNothing, reason: 'no screen, no chip');
    await tester.tap(find.text('شيف زاد'));
    await tester.pump();
    expect(opened, 1);
  });

  testWidgets('with disableAnimations the loop is not running', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _app(Scaffold(body: world())),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect((_lastLoop as AnimationController).isAnimating, isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('the loop runs normally', (tester) async {
    await tester.pumpWidget(_app(Scaffold(body: world())));
    await tester.pump(const Duration(milliseconds: 500));
    expect((_lastLoop as AnimationController).isAnimating, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets("the customer's own companion is the one drawn", (tester) async {
    const own = CompanionLook(persona: CompanionPersona.fella);
    await tester.pumpWidget(
      _app(
        Scaffold(body: world()),
        overrides: [companionLookProvider.overrideWithValue(own)],
      ),
    );
    await tester.pump();
    expect(tester.widget<CompanionOrb>(find.byType(CompanionOrb)).look, own);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with none saved, Zado is drawn', (tester) async {
    await tester.pumpWidget(_app(Scaffold(body: world())));
    await tester.pump();
    expect(
      tester.widget<CompanionOrb>(find.byType(CompanionOrb)).look,
      const CompanionLook(),
    );
    await tester.pumpWidget(const SizedBox());
  });

  group('the inventory world', () {
    final items = <InventoryItem>[
      const InventoryItem(
        id: '1',
        userId: 'u',
        itemName: 'لبن',
        quantity: 0,
        category: 'الألبان',
      ),
      const InventoryItem(
        id: '2',
        userId: 'u',
        itemName: 'أرز',
        quantity: 5,
        category: 'البقالة',
      ),
    ];

    Future<void> pumpInv(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      ZadScreens.worldScreen = (w) => (_) async {};
      await tester.pumpWidget(
        _app(
          const Scaffold(body: PantryView()),
          overrides: [
            nowProvider.overrideWithValue(() => DateTime.utc(2026, 9, 25, 9)),
            accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
            pantry.pantryControllerProvider.overrideWith(
              () => QuietPantry(pantry.PantryView(items: items)),
            ),
            shoppingControllerProvider.overrideWith(QuietShopping.new),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets('has no overflow at 360x640 and shows the real count', (
      tester,
    ) async {
      await pumpInv(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('المخزون'), findsOneWidget);
      expect(find.text('صنفين'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('screenshot: the inventory world', (tester) async {
      await loadZadFonts();
      await pumpInv(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../../build/screens/world_inventory.png'),
      );
      await tester.pumpWidget(const SizedBox());
    }, skip: Platform.environment['ZAD_SCREENS'] != '1');
  });
}

late Animation<double> _lastLoop;
