import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/prices/domain/prices.dart';
import 'package:zad/features/prices/presentation/prices_screen.dart';

Future<void> _show(WidgetTester tester, AreaTrends? trends) =>
    tester.pumpWidget(
      MaterialApp(
        theme: ZadTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(child: AreaTrendsSection(trends: trends)),
        ),
      ),
    );

void main() {
  testWidgets('a small market says why there is nothing, and the threshold', (
    tester,
  ) async {
    await _show(
      tester,
      const AreaTrends(items: <AreaTrend>[], minHouseholds: 5, days: 14),
    );

    expect(find.text('لسه مفيش ترند في سوقك'), findsOneWidget);
    expect(find.textContaining('5 بيوت مختلفة'), findsOneWidget);
  });

  testWidgets('no market asks for one first', (tester) async {
    await _show(
      tester,
      const AreaTrends(
        items: <AreaTrend>[],
        minHouseholds: 5,
        days: 14,
        noMarket: true,
      ),
    );

    expect(find.text('اختار بلدك الأول'), findsOneWidget);
  });

  testWidgets('trends show the item, its homes and its direction', (
    tester,
  ) async {
    await _show(
      tester,
      const AreaTrends(
        items: <AreaTrend>[
          AreaTrend(item: 'زيت', households: 7, direction: TrendDirection.up),
        ],
        minHouseholds: 5,
        days: 14,
      ),
    );

    expect(find.text('زيت'), findsOneWidget);
    expect(find.text('7 بيوت'), findsOneWidget);
    expect(find.bySemanticsLabel('بيزيد'), findsOneWidget);
    expect(find.text('لسه مفيش ترند في سوقك'), findsNothing);
  });
}
