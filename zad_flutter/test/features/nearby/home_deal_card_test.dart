import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/features/nearby/domain/home_deals.dart';
import 'package:zad/features/nearby/presentation/home_deals_carousel.dart';

import '../../support/fonts.dart';

void main() {
  setUpAll(loadZadFonts);

  // The bar went from 336 to 284 (ZAD_PLAN ١٠.٨). The fullest card — a
  // two-line name, a store code, a saving and an old price — has to fit it.
  testWidgets('the fullest card fits the shorter bar', (tester) async {
    final deal = homeDealsFromJson(<String, Object?>{
      'ok': true,
      'cards': <Object?>[
        <String, Object?>{
          'item': 'زيت عباد الشمس كريستال ٢٫٢ لتر عبوة عائلية', // l10n: data
          'store': 'هايبر وان التجمع الخامس فرع التسعين', // l10n: data
          'price': 1249.75,
          'price_before': 1499.5,
          'currency': 'EGP',
          'saving': 17,
          'why': 'favorite',
          'url': 'https://www.amazon.eg/dp/B000000000',
          'code': <String, Object?>{'code': 'RAMADAN2026', 'percent': 10},
        },
      ],
    }).single;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ZadTheme.light(),
          locale: const Locale('ar'),
          localizationsDelegates: ZadL10n.localizationsDelegates,
          supportedLocales: ZadL10n.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                height: HomeDealCard.height,
                child: HomeDealCard(deal: deal, image: null),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byTooltip(RegExp('RAMADAN2026')), findsOneWidget);
  });
}
