// Home's "من زاد": absent when nothing is pending; a dismissal asks why; a
// question is answered into the chat, not into a void.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/design/zad_theme.dart';
import 'package:zad/features/insights/application/insights_controller.dart';
import 'package:zad/features/insights/domain/insight.dart';
import 'package:zad/features/insights/presentation/insight_cards.dart';

class _Insights extends InsightsController {
  new(this.pending);

  final List<ZadInsight> pending;
  final List<String> calls = <String>[];

  @override
  InsightsView build() => InsightsView(pending: pending);

  @override
  Future<void> refresh({bool force = false}) async {}

  @override
  Future<void> dismiss(ZadInsight insight, {DismissReason? reason}) async =>
      calls.add('dismiss:${insight.id}:${reason?.wire}');

  @override
  Future<void> answer(ZadInsight question, String text) async =>
      calls.add('answer:${question.id}:$text');
}

void main() {
  late _Insights fake;

  Future<void> pump(WidgetTester tester, List<ZadInsight> pending) async {
    fake = _Insights(pending);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [insightsControllerProvider.overrideWith(() => fake)],
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: HomeInsightsSection()),
          ),
        ),
      ),
    );
  }

  testWidgets('nothing pending: nothing drawn', (tester) async {
    await pump(tester, const <ZadInsight>[]);
    expect(find.text('من زاد'), findsNothing);
  });

  testWidgets('an insight is dismissed with the reason chosen', (tester) async {
    await pump(tester, const <ZadInsight>[
      ZadInsight(id: 'a', title: 'اشتراكك بيتجدد', body: 'بكرة'),
    ]);
    expect(find.text('من زاد'), findsOneWidget);
    expect(find.text('معلومة'), findsOneWidget);

    await tester.tap(find.byTooltip('اقفل'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الرقم غلط'));
    await tester.pumpAndSettle();

    expect(fake.calls, <String>['dismiss:a:wrong_data']);
  });

  testWidgets('a question is answered, and "later" asks no reason', (
    tester,
  ) async {
    await pump(tester, const <ZadInsight>[
      ZadInsight(
        id: 'q',
        title: 'فاضل قد إيه من البنادول؟',
        body: '',
        kind: 'question',
      ),
    ]);
    expect(find.text('سؤال'), findsOneWidget);

    await tester.tap(find.text('جاوب'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'شريطين');
    await tester.tap(find.text('ابعت لزاد'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(fake.calls, <String>['answer:q:شريطين']);

    await tester.tap(find.byTooltip('مش دلوقتي'));
    await tester.pump();
    expect(fake.calls.last, 'dismiss:q:null');
  });
}
