// The map's promises: every area it draws can be opened to its real items,
// "اسأل زاد" puts a question in the composer and never sends one, and a phone
// that asks for less motion gets a still map.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/brain/application/knowledge_map_controller.dart';
import 'package:zad/features/brain/domain/knowledge_map.dart';
import 'package:zad/features/brain/presentation/knowledge_map_screen.dart';
import 'package:zad/features/chat/presentation/chat_screen.dart';
import 'package:zad/shared/chat/application/chat_controller.dart';

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

  Future<void> pump(WidgetTester tester, MapInputs inputs) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [
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
            // Still, so the test can settle — and the path a customer with
            // reduced motion takes.
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
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
    await tester.pumpAndSettle();
  }

  const inputs = MapInputs(
    limit: 5000,
    committed: 1200,
    available: 3300,
    subscriptions: <MapLine>[MapLine('نتفليكس', 200, detail: '200/شهر')],
    lowPantry: <MapStock>[MapStock('لبن', '1 علبة')],
  );

  testWidgets('draws the areas with real data and says how many', (
    tester,
  ) async {
    await pump(tester, inputs);

    expect(find.text('الميزانية'), findsOneWidget);
    expect(find.text('الاشتراكات والأقساط'), findsOneWidget);
    expect(find.text('المخزون'), findsOneWidget);
    // Empty areas are not drawn.
    expect(find.text('الديون'), findsNothing);
    // 3 areas + 1 subscription + 1 pantry item.
    expect(find.text('5 عنصر متصل'), findsOneWidget);
    expect(find.text('علاقة محسوبة فعليًا'), findsOneWidget);
  });

  testWidgets('an area opens to its items; the budget to its figures', (
    tester,
  ) async {
    await pump(tester, inputs);

    await tester.tap(find.text('المخزون'));
    await tester.pumpAndSettle();
    expect(find.text('لبن'), findsOneWidget);
    expect(find.text('1 علبة'), findsOneWidget);
    expect(find.text('فتح الشاشة'), findsOneWidget);

    await tester.tap(find.text('×'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الميزانية'));
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

    await tester.tap(find.text('المخزون'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اسأل زاد'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('وضّحلي أكتر عن المخزون'), findsOneWidget);
  });

  testWidgets('an empty map still shows the budget hub', (tester) async {
    await pump(tester, const MapInputs());
    expect(find.text('الميزانية'), findsOneWidget);
    expect(find.text('1 عنصر متصل'), findsOneWidget);
  });
}
