// One ad per AI request (owner, 11/11): the support assistant's answer
// carries an inline ad under it; before any answer, and on the failure text,
// there is none.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/support/data/support_assistant.dart';
import 'package:zad/features/support/presentation/help_support_screen.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/ads/presentation/inline_ad.dart';

class _Assistant implements SupportAssistant {
  new(this.reply);

  final String reply;

  @override
  Future<String> ask(String question) async => reply;
}

void main() {
  Future<void> ask(WidgetTester tester, String reply) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adsAllowedProvider.overrideWithValue(false),
          supportAssistantProvider.overrideWithValue(_Assistant(reply)),
        ],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: HelpSupportScreen(),
          ),
        ),
      ),
    );
    expect(find.byType(ZadInlineAd), findsNothing);
    await tester.enterText(find.byType(TextField), 'ازاي اضيف مصروف؟');
    await tester.tap(find.byTooltip('إرسال'));
    await tester.pumpAndSettle();
  }

  testWidgets('the assistant answer carries one inline ad', (tester) async {
    await ask(tester, 'دوس على الزرار الأخضر');
    expect(find.text('دوس على الزرار الأخضر'), findsOneWidget);
    expect(find.byType(ZadInlineAd), findsOneWidget);
  });

  testWidgets('the failure text shows no ad', (tester) async {
    await ask(tester, SupportAssistant.fallback);
    expect(find.text(SupportAssistant.fallback), findsOneWidget);
    expect(find.byType(ZadInlineAd), findsNothing);
  });
}
