// Behaviour, not pixels. The goldens next door are for looking at; these are
// the checks that should still fail a build on another machine.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/core/period/budget_period.dart';
import 'package:zad/core/period/payday.dart';
import 'package:zad/design/components/zad_balance_card.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/components/zad_pressable.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/zad_theme.dart';

void main() {
  setUpAll(tz_data.initializeTimeZones);

  Widget wrap(Widget child) => MaterialApp(
    theme: ZadTheme.light(),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: Center(child: child)),
    ),
  );

  group('ZadPressable', () {
    testWidgets('buzzes on press down, not on the callback', (tester) async {
      // The tap is what the user is asking about; waiting for the work to
      // finish before answering makes the app feel like it missed the touch.
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String? ?? '');
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      var taps = 0;
      await tester.pumpWidget(
        wrap(
          ZadPressable(
            onPressed: () => taps++,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ZadPressable)),
      );
      await tester.pump();

      expect(haptics, hasLength(1), reason: 'no haptic on press down');
      expect(taps, 0, reason: 'the callback ran before the finger lifted');

      await gesture.up();
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('a null callback disables the feedback too', (tester) async {
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics.add('x');
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        wrap(const ZadPressable(child: SizedBox(width: 100, height: 100))),
      );

      await tester.tap(find.byType(ZadPressable));
      await tester.pump();

      // A disabled surface that still shrinks and buzzes is telling the user it
      // did something.
      expect(haptics, isEmpty);
    });

    testWidgets('meets the minimum tap target when given one', (tester) async {
      await tester.pumpWidget(
        wrap(
          ZadPressable(
            onPressed: () {},
            child: const SizedBox(
              width: kZadMinTapTarget,
              height: kZadMinTapTarget,
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byType(ZadPressable));
      expect(size.width, greaterThanOrEqualTo(kZadMinTapTarget));
      expect(size.height, greaterThanOrEqualTo(kZadMinTapTarget));
    });
  });

  group('ZadBalanceCard', () {
    final now = DateTime.parse('2026-09-19T12:00:00Z');

    BudgetPeriod period({int? cycleStartDay}) => BudgetPeriod.at(
      at: now,
      country: 'EG',
      cycleStartDay: cycleStartDay,
      anchor: CycleAnchor.dayOfMonth,
    );

    Future<void> pumpCard(
      WidgetTester tester, {
      required int? cycleStartDay,
      double remaining = 4820.5,
      bool isStale = false,
    }) async {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 360,
            child: ZadBalanceCard(
              remaining: remaining,
              budget: 8000,
              currency: 'ج.م',
              period: period(cycleStartDay: cycleStartDay),
              now: now,
              isStale: isStale,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    testWidgets('counts the salary cycle, not the calendar month', (
      tester,
    ) async {
      // Paid on the 25th, asked on the 19th: the period runs 25 Aug – 25 Sep,
      // so five whole days remain — the 20th to the 24th. A calendar month
      // would have said eleven.
      await pumpCard(tester, cycleStartDay: 25);

      expect(find.textContaining('باقي 5'), findsOneWidget);
      expect(find.text('المتبقي في دورة الراتب'), findsOneWidget);
    });

    testWidgets('says "this month" when no payday is known', (tester) async {
      // Claiming a salary cycle for an account that never told us its payday
      // asserts a fact nobody supplied.
      await pumpCard(tester, cycleStartDay: null);

      expect(find.text('المتبقي هذا الشهر'), findsOneWidget);
      expect(find.text('المتبقي في دورة الراتب'), findsNothing);
    });

    testWidgets('an unconfirmed figure is marked, not hidden', (tester) async {
      await pumpCard(tester, cycleStartDay: 25, isStale: true);

      // The figure is still there — showing the cached number is the point —
      // and the card carries a mark saying it is not confirmed.
      expect(find.text('4,820.5'), findsOneWidget);
      final marks = tester
          .widgetList<Container>(find.byType(Container))
          .where(
            (c) => (c.decoration as BoxDecoration?)?.shape == BoxShape.circle,
          );
      expect(marks, isNotEmpty, reason: 'no pending mark on a stale figure');
    });

    testWidgets('announces itself to a screen reader', (tester) async {
      await pumpCard(tester, cycleStartDay: 25);

      final semantics = tester.getSemantics(find.byType(ZadBalanceCard).first);
      expect(semantics.label, contains('المتبقي'));
      expect(semantics.label, contains('4,820.5'));
    });
  });

  group('ZadEmptyState', () {
    testWidgets('shows a glyph, a title and guidance', (tester) async {
      // The house rule: a list-backed screen never renders a blank body. A bare
      // empty list is indistinguishable from a failed load.
      await tester.pumpWidget(
        wrap(
          const ZadEmptyState(
            icon: ZadIcons.inventory,
            title: 'المخزن فاضي',
            message: 'صوّر فاتورة أو أضف أول حاجة.',
          ),
        ),
      );

      expect(find.byIcon(ZadIcons.inventory), findsOneWidget);
      expect(find.text('المخزن فاضي'), findsOneWidget);
      expect(find.text('صوّر فاتورة أو أضف أول حاجة.'), findsOneWidget);
    });

    testWidgets('carries at most the one action it was given', (tester) async {
      await tester.pumpWidget(
        wrap(
          ZadEmptyState(
            icon: ZadIcons.failed,
            title: 'تعذّر التحميل',
            message: 'جرّب تاني.',
            tone: ZadEmptyTone.problem,
            action: FilledButton(onPressed: () {}, child: const Text('إعادة')),
          ),
        ),
      );

      expect(find.byType(FilledButton), findsOneWidget);
    });
  });
}
