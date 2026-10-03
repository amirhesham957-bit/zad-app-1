// «ضيفهم» on a family-chat need in the brief: each item onto the shopping
// list, then its suggestion is done — and nothing else is touched.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/brain/domain/daily_brief.dart';
import 'package:zad/shared/brain/presentation/daily_brief_lines.dart';
import 'package:zad/shared/insights/application/insights_controller.dart';
import 'package:zad/shared/insights/domain/insight.dart';
import 'package:zad/shared/inventory/application/shopping_controller.dart';

import '../../support/quiet_household.dart';

class _Insights extends InsightsController {
  new(this.pending);

  final List<ZadInsight> pending;
  final List<String> acted = <String>[];

  @override
  InsightsView build() => InsightsView(pending: pending);

  @override
  Future<void> refresh({bool force = false}) async {}

  @override
  Future<void> markActed(ZadInsight insight) async => acted.add(insight.id);
}

ZadInsight _need(String id, String item) =>
    ZadInsight.fromJson(<String, dynamic>{
      'id': id,
      'kind': 'insight',
      'surface': 'home_card',
      'title': item,
      'body': 'ماما قال في شات العيلة إنه ناقص',
      'about_item': item,
      'action_type': kShoppingAddAction,
    });

void main() {
  testWidgets('each need goes on the list and its suggestion is done', (
    tester,
  ) async {
    final shopping = QuietShopping();
    final insights = _Insights(<ZadInsight>[
      _need('i1', 'عيش'),
      _need('i2', 'بيض'),
      ZadInsight.fromJson(const <String, dynamic>{
        'id': 'other',
        'kind': 'insight',
        'surface': 'home_card',
        'title': 'حاجة تانية',
        'body': '…',
      }),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shoppingControllerProvider.overrideWith(() => shopping),
          insightsControllerProvider.overrideWith(() => insights),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (_, ref, _) => TextButton(
              onPressed: () => addFamilyNeeds(ref, const <FamilyNeed>[
                (id: 'i1', item: 'عيش', who: 'ماما'),
                (id: 'i2', item: 'بيض', who: 'ماما'),
              ]),
              child: const Text('ضيفهم'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ضيفهم'));
    await tester.pumpAndSettle();
    expect(shopping.added, <String>['عيش', 'بيض']);
    expect(insights.acted, <String>['i1', 'i2']);
  });
}
