// The brain is one dark world: the map's filter chips on top of the sphere,
// an honest empty state when there is nothing to draw, every card of the old
// hub still there, and a chip narrowing the map to an area and what it
// touches.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/features/brain/application/knowledge_map_controller.dart';
import 'package:zad/features/brain/domain/knowledge_map.dart';
import 'package:zad/features/brain/presentation/brain_hub_screen.dart';

import '../../support/fonts.dart';
import '../../support/quiet_household.dart';

class _Map extends KnowledgeMapController {
  new(this.inputs);

  final MapInputs inputs;

  @override
  KnowledgeMapView build() =>
      KnowledgeMapView(map: buildKnowledgeMap(inputs), currency: 'EGP');

  @override
  Future<void> refresh() async {}
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    MapInputs inputs, {
    bool keepSize = false,
  }) async {
    if (!keepSize) {
      tester.view
        ..physicalSize = const Size(1080, 2400)
        ..devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...quietOrbOverrides,
          knowledgeMapControllerProvider.overrideWith(() => _Map(inputs)),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          locale: const Locale('ar'),
          localizationsDelegates: ZadL10n.localizationsDelegates,
          supportedLocales: ZadL10n.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const BrainHubScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const inputs = MapInputs(
    limit: 5000,
    committed: 1200,
    available: 3300,
    subscriptions: <MapLine>[MapLine('نتفليكس', 200, detail: '200/شهر')],
    lowPantry: <MapStock>[MapStock('لبن', '1 علبة')],
  );

  testWidgets('renders the title, the state line, the filters and the map', (
    tester,
  ) async {
    await pump(tester, inputs);

    expect(find.text('عقل زاد'), findsOneWidget);
    expect(find.text('متصل ويتعلم'), findsOneWidget);
    expect(find.text('الكل'), findsOneWidget);
    // A chip and a node each: the area is on the map and in the filters.
    expect(find.text('المخزون'), findsNWidgets(2));
    expect(find.text('5 عنصر متصل'), findsOneWidget);
  });

  testWidgets('says so when there is nothing to draw yet', (tester) async {
    await pump(tester, const MapInputs());

    expect(find.text('زاد لسه بيتعلم عنك'), findsOneWidget);
    expect(find.text('الكل'), findsNothing);
  });

  testWidgets('a chip keeps one area and what it touches', (tester) async {
    await pump(
      tester,
      const MapInputs(
        limit: 5000,
        committed: 1200,
        subscriptions: <MapLine>[MapLine('نتفليكس', 200)],
        lowPantry: <MapStock>[MapStock('لبن', '1 علبة')],
        pendingShopping: <MapStock>[MapStock('لبن', '1')],
      ),
    );

    // The subscriptions touch the pantry and the budget, never the shopping
    // list.
    final shopping = find.text('قائمة التسوق');
    final before = shopping.evaluate().length;
    expect(before, greaterThan(0));
    // The chip row scrolls sideways: bring the chip into view.
    await tester.ensureVisible(find.text('الاشتراكات والأقساط').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('الاشتراكات والأقساط').first);
    await tester.pumpAndSettle();
    expect(shopping.evaluate().length, lessThan(before));

    await tester.ensureVisible(find.text('الكل'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الكل'));
    await tester.pumpAndSettle();
    expect(shopping.evaluate().length, before);
  });

  testWidgets('keeps every card of the old hub', (tester) async {
    await pump(tester, inputs);

    for (final title in <String>[
      'فريق زاد',
      'زاد عارف عني إيه',
      'شبكة زاد',
      'خريطة زاد',
      'سجل تعديلات زاد',
      'صحة عقل زاد',
    ]) {
      await tester.scrollUntilVisible(
        find.text(title),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(title), findsOneWidget);
    }
  });

  // For the owner's review only: `ZAD_SCREENS=1 flutter test --update-goldens
  // test/features/brain/brain_world_test.dart` writes
  // build/screens/world_brain.png. Skipped in a normal run.
  testWidgets('screenshot: the dark brain world', (tester) async {
    await loadZadFonts();
    tester.view
      ..physicalSize = const Size(860, 1864)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await pump(tester, inputs, keepSize: true);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../build/screens/world_brain.png'),
    );
  }, skip: Platform.environment['ZAD_SCREENS'] != '1');
}
