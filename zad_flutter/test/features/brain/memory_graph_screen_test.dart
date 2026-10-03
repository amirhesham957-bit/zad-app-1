// شبكة زاد on screen: empty, a failure with a retry, each entity in the list
// opening what زاد knows about it, and «صدّر لأوبسيديان» handing over the
// vault.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
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
    Future<MemoryGraph> Function() graph,
  ) async {
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
}
