import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/nearby/presentation/home_deals_carousel.dart';
import 'package:zad/shared/campaigns/domain/campaign.dart';

void main() {
  Campaign campaign({String? name}) => Campaign.fromJson(<String, dynamic>{
    'id': 'wf',
    'event_key': 'white_friday',
    'event_name': ?name,
    'from_md': '11-20',
    'to_md': '11-30',
    'theme_primary': '#4C1D95',
    'theme_secondary': '#9A3412',
    'badge': '🛍️',
    'particles': 'confetti',
    'banner_title': 'الجمعة البيضاء', // l10n: data
    'banner_body': 'عروض',
    'cta_text': 'وريني',
    'cta_prompt': 'وريني العروض',
  })!;

  Future<void> pump(WidgetTester tester, Campaign c) => tester.pumpWidget(
    MaterialApp(
      theme: ZadTheme.light(),
      home: Scaffold(
        body: Center(child: OccasionMark(campaign: c)),
      ),
    ),
  );

  // HOME_REVIEW ٢: the occasion marks the deals' title in its own colour.
  testWidgets('the occasion beside the deals title: its badge, its name, its '
      'colour', (tester) async {
    await pump(tester, campaign(name: 'الجمعة البيضاء')); // l10n: data
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.data, '🛍️ الجمعة البيضاء'); // l10n: data
    expect(text.style?.color, const Color(0xFF4C1D95));
  });

  testWidgets('without a name, the badge alone', (tester) async {
    await pump(tester, campaign());
    expect(find.text('🛍️'), findsOneWidget);
  });
}
