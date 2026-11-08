// شبكة زاد on screen: empty, a failure with a retry, each entity in the list
// opening what زاد knows about it, and «صدّر لأوبسيديان» handing over the
// vault.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/features/brain/data/memory_graph_remote.dart';
import 'package:zad/features/brain/domain/memory_graph.dart';
import 'package:zad/features/brain/presentation/memory_graph_screen.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';

final _graph = MemoryGraph.fromRows(
  entityRows: const <Map<String, dynamic>>[
    <String, dynamic>{'id': 'mum', 'kind': 'person', 'name': 'ماما'},
    <String, dynamic>{'id': 'tea', 'kind': 'item', 'name': 'شاي'},
  ],
  mentionRows: const <Map<String, dynamic>>[
    <String, dynamic>{'memory_id': 'n1', 'entity_id': 'mum'},
    <String, dynamic>{'memory_id': 'n1', 'entity_id': 'tea'},
  ],
  noteRows: const <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'n1',
      'note': 'ماما بتحب الشاي بالنعناع',
      'valid_until': '2026-10-09T21:00:00+00:00',
    },
  ],
  linkRows: const <Map<String, dynamic>>[],
);

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    await initializeDateFormatting('ar');
  });

  late Map<String, String> shared;

  Future<void> pump(
    WidgetTester tester,
    Future<MemoryGraph> Function() graph, {
    bool localized = false,
  }) async {
    shared = <String, String>{};
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memoryGraphProvider.overrideWith((ref) => graph()),
          vaultSharerProvider.overrideWithValue((files) async {
            shared = files;
          }),
          accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
          nowProvider.overrideWithValue(() => DateTime.utc(2026, 10, 3, 9)),
        ],
        child: MaterialApp(
          theme: ZadTheme.light(),
          localizationsDelegates: localized
              ? ZadL10n.localizationsDelegates
              : null,
          supportedLocales: localized
              ? ZadL10n.supportedLocales
              : const <Locale>[Locale('en', 'US')],
          // Still, so the test can settle — and the path a customer with
          // reduced motion takes.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: MemoryGraphScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('nothing known yet says so, and there is nothing to export', (
    tester,
  ) async {
    await pump(tester, () async => const MemoryGraph());
    expect(find.text('لسه مفيش شبكة'), findsOneWidget);
    final export = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.ios_share),
    );
    expect(export.onPressed, isNull);
  });

  testWidgets('a failure says so and offers to try again', (tester) async {
    await pump(tester, () async => throw StateError('offline'));
    expect(find.text('مقدرتش أجيب الشبكة'), findsOneWidget);
    expect(find.text('جرّب تاني'), findsOneWidget);
  });

  testWidgets('each entity is listed with its kind and count, and opens what '
      'زاد knows about it', (tester) async {
    await pump(tester, () async => _graph);
    expect(find.text('ماما'), findsOneWidget);
    expect(find.text('شخص · 1 ملاحظة'), findsOneWidget);
    await tester.tap(find.text('ماما'));
    await tester.pumpAndSettle();
    expect(find.text('ماما بتحب الشاي بالنعناع'), findsOneWidget);
    expect(find.text('لحد 9 أكتوبر · شاي'), findsOneWidget);
  });

  testWidgets('«صدّر لأوبسيديان» hands over the index and a note per entity', (
    tester,
  ) async {
    await pump(tester, () async => _graph);
    await tester.tap(find.byTooltip('صدّر لأوبسيديان'));
    await tester.pumpAndSettle();
    expect(shared.keys, containsAll(<String>['زاد.md', 'ماما.md', 'شاي.md']));
    expect(shared['زاد.md'], contains('date: 2026-10-03'));
    expect(shared['ماما.md'], contains('(لحد 9 أكتوبر) — [[شاي]]'));
  });

  group('the graph under the finger', () {
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

    Offset nodeOn(WidgetTester tester, String id) {
      final canvas = tester.getRect(
        find.byKey(const ValueKey<String>('graph-canvas')),
      );
      final point = layoutGraph(<String>['mum', 'tea'], _graph.edges)[id]!;
      return canvas.topLeft + Offset(point.x, point.y) * canvas.width;
    }

    testWidgets('a circle buzzes and opens what زاد knows about it', (
      tester,
    ) async {
      await pump(tester, () async => _graph);
      await tester.tapAt(nodeOn(tester, 'mum'));
      await tester.pumpAndSettle();
      expect(haptics, <String>['HapticFeedbackType.selectionClick']);
      expect(find.text('ماما بتحب الشاي بالنعناع'), findsOneWidget);
    });

    testWidgets('a tap on empty canvas does nothing', (tester) async {
      await pump(tester, () async => _graph);
      final canvas = tester.getRect(
        find.byKey(const ValueKey<String>('graph-canvas')),
      );
      await tester.tapAt(canvas.topLeft + const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(haptics, isEmpty);
      expect(find.text('ماما بتحب الشاي بالنعناع'), findsNothing);
    });

    testWidgets('a pinch zooms, a vertical drag moves it, and the reset '
        'brings it back', (tester) async {
      await pump(tester, () async => _graph, localized: true);
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final matrix = viewer.transformationController!;
      final middle = tester.getCenter(find.byType(InteractiveViewer));

      final one = await tester.startGesture(middle - const Offset(0, 40));
      final two = await tester.startGesture(middle + const Offset(0, 40));
      await tester.pump();
      await one.moveBy(const Offset(0, -80));
      await two.moveBy(const Offset(0, 80));
      await tester.pump();
      await one.up();
      await two.up();
      await tester.pumpAndSettle();
      final zoomed = matrix.value.getMaxScaleOnAxis();
      expect(zoomed, greaterThan(1.2));

      // The drag the old list above it used to swallow.
      final before = matrix.value.getTranslation().y;
      await tester.dragFrom(middle, const Offset(0, 60));
      await tester.pumpAndSettle();
      expect(matrix.value.getTranslation().y, isNot(before));

      final reset = ZadL10n.of(tester.element(find.byType(MemoryGraphScreen)))
          .memoryGraphResetView;
      await tester.tap(find.byTooltip(reset));
      await tester.pumpAndSettle();
      expect(matrix.value.isIdentity(), isTrue);
      expect(find.byTooltip(reset), findsNothing);
    });
  });
}
