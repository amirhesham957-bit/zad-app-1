import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/features/nearby/domain/shein_offers.dart';
import 'package:zad/features/nearby/presentation/home_deals_carousel.dart';

import '../../support/fonts.dart';

const String _real =
    'https://onelink.shein.com/60/67x9gydalfpz?ismg_ol=4TYBWTPjnSB_01_KOC-C';

void main() {
  setUpAll(loadZadFonts);

  test('SHEIN goes to Saudi and the Emirates only — Egypt stays on Amazon', () {
    expect(sheinMarket('SA'), isTrue);
    expect(sheinMarket('ae'), isTrue);
    expect(sheinMarket('EG'), isFalse);
    expect(sheinMarket(null), isFalse);
  });

  test('only SHEIN dashboard links are kept — a plain product link earns '
      'nothing', () {
    final offers = sheinOffersFromJson(<Object?>[
      <String, Object?>{'id': 1, 'title': 'فستان', 'affiliate_url': _real},
      <String, Object?>{
        'id': 2,
        'title': 'بلوزة',
        'affiliate_url':
            'https://ar.shein.com/p-1.html?aff_id=4559428113&ref_code=x',
      },
      <String, Object?>{
        'id': 3,
        'title': 'شنطة',
        'affiliate_url': 'https://onelink.shein.com.evil.example/60/abc',
      },
      <String, Object?>{'id': 4, 'title': ' ', 'affiliate_url': _real},
      <String, Object?>{
        'id': 5,
        'title': 'طقم مفارش',
        'affiliate_url': _real,
        'image_url': 'http://insecure.example/a.jpg',
        'coupon_code': 'SUMMER10',
      },
    ]);
    expect(<String>[for (final o in offers) o.id], <String>['1', '5']);
    expect(offers.last.image, isNull);
    expect(offers.last.code, 'SUMMER10');
    expect(offers.first.code, isNull);
  });

  test("the owner's referral code is never in the app (it is not a shopper "
      'discount, owner 11/11)', () {
    final hits = <String>[
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            f.readAsStringSync().contains('B8U6U'))
          f.path,
    ];
    expect(hits, isEmpty);
  });

  testWidgets('a full SHEIN card fits the deals bar', (tester) async {
    final offer = sheinOffersFromJson(<Object?>[
      <String, Object?>{
        'id': 1,
        'title': 'طقم مفارش سرير قطن مصري ٦ قطع بألوان هادية للصيف والشتا',
        'affiliate_url': _real,
        'coupon_code': 'SUMMER10',
      },
    ]).single;
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
                child: SheinOfferCard(offer: offer),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('تسوّق على SHEIN'), findsOneWidget);
    expect(find.byTooltip(RegExp('SUMMER10')), findsOneWidget);
  });
}
