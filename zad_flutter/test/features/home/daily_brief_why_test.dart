// ZAD_PLAN ٦.٤: every line of «موجز زاد النهارده» has a «ليه؟» that opens,
// in place, the figures the line was decided on.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/shared/brain/domain/daily_brief.dart';
import 'package:zad/shared/brain/presentation/daily_brief_lines.dart';

void main() {
  final l10n = lookupZadL10n(const Locale('ar'));

  test("the words carry the line's own numbers", () {
    expect(
      briefWhyText(
        l10n,
        const BriefWhy(
          BriefWhyKind.runningOut,
          name: 'جبنة',
          left: 1,
          perDay: 0.7,
        ),
      ),
      'جبنة: فاضل 1، وبتستهلك حوالي 0.7 في اليوم.',
    );
    expect(
      briefWhyText(
        l10n,
        const BriefWhy(
          BriefWhyKind.shortage,
          name: 'زيت',
          left: 1,
          threshold: 2,
        ),
      ),
      contains('(2)'),
    );
    expect(
      briefWhyText(l10n, const BriefWhy(BriefWhyKind.missed, count: 2)),
      contains(': 2.'),
    );
  });

  testWidgets('«ليه؟» opens the reason in place', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyBriefProvider.overrideWithValue(const <BriefItem>[
            BriefItem(
              kind: BriefKind.renewal,
              title: 'Netflix بكرة',
              detail: '120 ج.م',
              why: BriefWhy(BriefWhyKind.renewal, name: 'Netflix'),
            ),
          ]),
        ],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: DailyBriefLines(empty: SizedBox())),
          ),
        ),
      ),
    );
    expect(find.textContaining('متسجل في اشتراكاتك'), findsNothing);
    await tester.tap(find.text('ليه؟'));
    await tester.pump();
    expect(find.textContaining('«Netflix» متسجل في اشتراكاتك'), findsOneWidget);
    expect(find.text('ليه؟'), findsNothing);
  });
}
