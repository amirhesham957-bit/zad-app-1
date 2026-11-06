import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/profile/data/consumption_pattern_remote.dart';
import 'package:zad/features/profile/domain/consumption_pattern.dart';
import 'package:zad/features/profile/presentation/consumption_pattern_screen.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';

class _Budget extends BudgetController {
  @override
  BudgetView build() => const BudgetView();
}

final Map<String, dynamic> _row = <String, dynamic>{
  'avg_weekly_spending': 850.4,
  'favorite_stores': <Object?>[
    <String, dynamic>{'store': 'كازيون', 'visits': 6, 'share': 41},
    <String, dynamic>{'store': '', 'visits': 1},
    'junk',
  ],
  'shopping_rhythm': <String, dynamic>{
    'top_weekday': 5,
    'top_part': 'evening',
    'typical_gap_days': 4,
    'shopping_days': 9,
  },
  'item_cycles': <Object?>[
    <String, dynamic>{
      'item': 'عيش',
      'cycle_days': 2,
      'learned': true,
      'due_in_days': 0,
      'due': true,
    },
    <String, dynamic>{
      'item': 'زيت',
      'cycle_days': 14,
      'set_by_customer': true,
      'due_in_days': 9,
      'due': false,
    },
    <String, dynamic>{'item': 'سكر', 'cycle_days': 0},
  ],
  'last_updated_at': '2026-11-05T23:00:00Z',
};

void main() {
  group('reading the profile row', () {
    test('keeps what is well formed and drops the rest', () {
      final p = consumptionPatternFromJson(_row)!;
      expect(p.weeklySpending, 850.4);
      expect(p.stores.single.store, 'كازيون');
      expect(p.rhythm.topWeekday, 5);
      expect(p.rhythm.topPart, 'evening');
      expect(p.items.map((i) => i.item), <String>['عيش', 'زيت']);
      expect(p.items.first.source, CycleSource.learned);
      expect(p.items.last.source, CycleSource.customer);
      expect(hasLearnedAnything(p), isTrue);
    });

    test('no row, or a row with nothing learned yet', () {
      expect(consumptionPatternFromJson(null), isNull);
      final empty = consumptionPatternFromJson(<String, dynamic>{
        'favorite_stores': <Object?>[],
        'shopping_rhythm': <String, dynamic>{},
        'item_cycles': <Object?>[],
      })!;
      expect(hasLearnedAnything(empty), isFalse);
      expect(empty.rhythm.topWeekday, isNull);
    });

    test('an unknown part of day or weekday is not shown', () {
      final p = consumptionPatternFromJson(<String, dynamic>{
        'shopping_rhythm': <String, dynamic>{
          'top_weekday': 9,
          'top_part': 'dawn',
          'shopping_days': 5,
        },
      })!;
      expect(p.rhythm.topWeekday, isNull);
      expect(p.rhythm.topPart, isNull);
    });
  });

  group('the page', () {
    Future<void> pump(
      WidgetTester tester,
      Future<ConsumptionPattern?> Function() read,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            consumptionPatternProvider.overrideWith((ref) => read()),
            budgetControllerProvider.overrideWith(_Budget.new),
          ],
          child: MaterialApp(
            theme: ZadTheme.light(),
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: ConsumptionPatternScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows stores, rhythm and cycles', (tester) async {
      await pump(tester, () async => consumptionPatternFromJson(_row));
      expect(find.text('كازيون'), findsOneWidget);
      expect(find.text('عيش'), findsOneWidget);
      expect(find.text('وقت شراه'), findsOneWidget);
      expect(find.textContaining('انت اللي حددتها'), findsOneWidget);
      expect(find.textContaining('850'), findsOneWidget);
    });

    testWidgets('nothing learned yet is a real empty state', (tester) async {
      await pump(tester, () async => null);
      expect(find.text('لسه بتعلّم'), findsOneWidget);
    });

    testWidgets('a failed read says so, not «still learning»', (tester) async {
      await pump(tester, () async => throw StateError('offline'));
      expect(find.text('لسه بتعلّم'), findsNothing);
      expect(find.textContaining('مقدرتش أقرا'), findsOneWidget);
    });
  });
}
