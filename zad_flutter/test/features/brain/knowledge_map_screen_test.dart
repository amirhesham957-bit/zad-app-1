// The map's promises: every area it draws can be opened to its real items,
// "اسأل زاد" puts a question in the composer and never sends one, a node can
// be dragged and springs back, a pinch looks closer and eases back, the chips
// dim what they do not pick, and a phone that asks for less motion gets a
// still map.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/brain/application/knowledge_map_controller.dart';
import 'package:zad/features/brain/domain/knowledge_map.dart';
import 'package:zad/features/brain/presentation/brain_map_stage.dart';
import 'package:zad/features/brain/presentation/knowledge_map_screen.dart';
import 'package:zad/features/chat/presentation/chat_screen.dart';
import 'package:zad/shared/chat/application/chat_controller.dart';

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

class _Chat extends ChatController {
  @override
  ChatView build() => const ChatView();
}

void main() {
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester,
    MapInputs inputs, {
    bool still = true,
  }) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [
        ...quietOrbOverrides,
        knowledgeMapControllerProvider.overrideWith(() => _Map(inputs)),
        chatControllerProvider.overrideWith(_Chat.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ZadTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: still),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            ),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showKnowledgeMap(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    if (still) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
    }
  }

  const inputs = MapInputs(
    limit: 5000,
    committed: 1200,
    available: 3300,
    subscriptions: <MapLine>[MapLine('نتفليكس', 200, detail: '200/شهر')],
    lowPantry: <MapStock>[MapStock('لبن', '1 علبة')],
  );

  Finder node(MapDomainKey k) => find.byKey(brainNodeKey(k));
  double opacity(WidgetTester tester, MapDomainKey k) => tester
      .widget<Opacity>(
        find.descendant(of: node(k), matching: find.byType(Opacity)),
      )
      .opacity;

  testWidgets('draws the areas with real data and says how many', (
    tester,
  ) async {
    await pump(tester, inputs);

    expect(node(MapDomainKey.budget), findsOneWidget);
    expect(node(MapDomainKey.subscriptions), findsOneWidget);
    expect(node(MapDomainKey.pantry), findsOneWidget);
    // Empty areas are not drawn.
    expect(node(MapDomainKey.debts), findsNothing);
    // 3 areas + 1 subscription + 1 pantry item.
    expect(find.text('5 عنصر متصل'), findsOneWidget);
    expect(find.text('علاقة محسوبة فعليًا'), findsOneWidget);
    // The stability index and the decisions today, in words.
    expect(find.text('مؤشر الثبات'), findsOneWidget);
    expect(find.text('قرارات النهارده'), findsOneWidget);
  });

  testWidgets('an area opens to its items; the budget to its figures', (
    tester,
  ) async {
    await pump(tester, inputs);

    await tester.tap(node(MapDomainKey.pantry));
    await tester.pumpAndSettle();
    expect(find.text('لبن'), findsOneWidget);
    expect(find.text('1 علبة'), findsOneWidget);
    expect(find.text('فتح الشاشة'), findsOneWidget);

    await tester.tap(find.text('×'));
    await tester.pumpAndSettle();
    await tester.tap(node(MapDomainKey.budget));
    await tester.pumpAndSettle();
    expect(find.text('محجوز'), findsOneWidget);
    expect(find.text('3,300 EGP'), findsOneWidget);
    expect(find.text('1,200 EGP'), findsOneWidget);
    // Kotlin's budget panel offers «اسأل زاد» only.
    expect(find.text('فتح الشاشة'), findsNothing);
  });

  testWidgets('«اسأل زاد» puts the question in the composer, unsent', (
    tester,
  ) async {
    await pump(tester, inputs);

    await tester.tap(node(MapDomainKey.pantry));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اسأل زاد'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('وضّحلي أكتر عن المخزون'), findsOneWidget);
  });

  testWidgets('an empty map says so instead of drawing nothing', (
    tester,
  ) async {
    await pump(tester, const MapInputs());
    expect(find.text('زاد لسه بيتعلم عنك'), findsOneWidget);
    expect(node(MapDomainKey.budget), findsNothing);
  });

  group('under the finger', () {
    late List<String> haptics;

    setUp(() {
      haptics = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              haptics.add(call.arguments as String);
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('a node buzzes when it is pressed, and an item asks', (
      tester,
    ) async {
      await pump(tester, inputs);
      await tester.tap(node(MapDomainKey.pantry));
      await tester.pumpAndSettle();
      expect(haptics, contains('HapticFeedbackType.selectionClick'));

      haptics.clear();
      await tester.tap(find.text('لبن'));
      await tester.pumpAndSettle();
      expect(haptics, contains('HapticFeedbackType.selectionClick'));
      // An item asks about itself, unsent.
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.text('وضّحلي أكتر عن لبن'), findsOneWidget);
    });

    testWidgets('a dragged node follows the finger and springs back', (
      tester,
    ) async {
      await pump(tester, inputs);
      final before = tester.getCenter(node(MapDomainKey.pantry));

      final g = await tester.startGesture(before - const Offset(0, 14));
      await tester.pump();
      await g.moveBy(const Offset(60, 20));
      await tester.pump();
      await g.moveBy(const Offset(10, 0));
      await tester.pump();
      expect(
        (tester.getCenter(node(MapDomainKey.pantry)) - before).distance,
        greaterThan(40),
      );
      await g.up();
      await tester.pumpAndSettle();
      expect(tester.getCenter(node(MapDomainKey.pantry)), before);
    });

    testWidgets('a pinch looks closer, then eases back', (tester) async {
      await pump(tester, inputs);
      Offset core() => tester.getCenter(find.byType(BrainMapStage));
      double spread() =>
          (tester.getCenter(node(MapDomainKey.pantry)) - core()).distance;
      final before = spread();
      final middle = core();

      final one = await tester.startGesture(middle - const Offset(40, 0));
      final two = await tester.startGesture(middle + const Offset(40, 0));
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await one.moveBy(const Offset(-30, 0));
        await two.moveBy(const Offset(30, 0));
        await tester.pump();
      }
      expect(spread(), greaterThan(before * 1.2));
      await one.up();
      await two.up();
      await tester.pumpAndSettle();
      expect(spread(), closeTo(before, 0.5));
    });
  });

  testWidgets('a chip dims what it does not pick; «الكل» brightens it', (
    tester,
  ) async {
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
    expect(opacity(tester, MapDomainKey.shopping), 1);

    // The subscriptions touch the pantry and the budget, never the shopping
    // list.
    final chip = find.descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.text('الاشتراكات والأقساط'),
    );
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(opacity(tester, MapDomainKey.shopping), lessThan(1));
    expect(opacity(tester, MapDomainKey.subscriptions), 1);
    expect(opacity(tester, MapDomainKey.pantry), 1);

    final all = find.descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.text('الكل'),
    );
    await tester.ensureVisible(all);
    await tester.pumpAndSettle();
    await tester.tap(all);
    await tester.pumpAndSettle();
    expect(opacity(tester, MapDomainKey.shopping), 1);
  });

  group('motion', () {
    testWidgets('reduced motion is a still layout', (tester) async {
      await pump(tester, inputs);
      final before = tester.getCenter(node(MapDomainKey.pantry));
      await tester.pump(const Duration(seconds: 3));
      expect(tester.getCenter(node(MapDomainKey.pantry)), before);
    });

    testWidgets('with motion, the nodes drift', (tester) async {
      await pump(tester, inputs, still: false);
      final before = tester.getCenter(node(MapDomainKey.pantry));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.getCenter(node(MapDomainKey.pantry)), isNot(before));
    });
  });
}
