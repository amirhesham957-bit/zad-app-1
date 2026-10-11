// Home's "من زاد": absent when nothing is pending; a dismissal asks why; a
// question is answered into the chat, not into a void.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/insights/presentation/insight_cards.dart';
import 'package:zad/shared/insights/application/insights_controller.dart';
import 'package:zad/shared/insights/domain/insight.dart';

class _Insights extends InsightsController {
  new(this.pending);

  final List<ZadInsight> pending;
  final List<String> calls = <String>[];
  final List<String> seen = <String>[];

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

  @override
  Future<void> markSeen(List<ZadInsight> shown) async =>
      seen.add(shown.map((i) => i.id).join(','));
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

  testWidgets('nothing pending: nothing drawn, nothing reported', (
    tester,
  ) async {
    await pump(tester, const <ZadInsight>[]);
    await tester.pump();
    expect(find.text('رؤية زاد الذكي ✨'), findsNothing);
    expect(fake.seen, isEmpty);
  });

  testWidgets('the cards drawn on Home are reported shown, after the frame', (
    tester,
  ) async {
    await pump(tester, const <ZadInsight>[
      ZadInsight(id: 'a', title: 'اشتراكك بيتجدد', body: 'بكرة'),
      ZadInsight(id: 'b', title: 'بيتادرم قرب يخلص', body: 'فاضل ٢'),
      ZadInsight(id: 'bell', title: 'في الإشعارات', body: '', surface: 'bell'),
    ]);
    await tester.pump();
    // Home's two, not the bell's: that one is reported where it is drawn.
    expect(fake.seen, contains('a,b'));
    expect(fake.seen.where((c) => c.contains('bell')), isEmpty);
  });

  testWidgets('an insight is dismissed with the reason chosen', (tester) async {
    await pump(tester, const <ZadInsight>[
      ZadInsight(id: 'a', title: 'اشتراكك بيتجدد', body: 'بكرة'),
    ]);
    expect(find.text('رؤية زاد الذكي ✨'), findsOneWidget);
    expect(find.text('معلومة'), findsOneWidget);

    // The card pulses forever, so no pumpAndSettle.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('الرقم غلط'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

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
    expect(find.text('فاضل قد إيه من البنادول؟'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline), findsOneWidget);

    // Kotlin's card: the answer field is open, no "answer" step first.
    await tester.enterText(find.byType(TextField), 'شريطين');
    await tester.pump();
    await tester.tap(find.text('إرسال'));
    await tester.pump();
    expect(fake.calls, <String>['answer:q:شريطين']);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(fake.calls.last, 'dismiss:q:null');
  });
}
