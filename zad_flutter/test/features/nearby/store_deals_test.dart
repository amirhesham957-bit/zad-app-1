import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/nearby/domain/store_deals.dart';
import 'package:zad/shared/affiliate/domain/affiliate.dart';

AffiliateProduct _product(
  String name, {
  String? image,
  List<String> keywords = const [],
}) => (
  id: name,
  nameAr: name,
  asin: null,
  asinVerified: false,
  imageUrl: image,
  averagePriceSar: 10,
  isActive: true,
  keywords: keywords,
  priceCheckedAt: null,
);

void main() {
  test('reads the server answer and drops malformed rows', () {
    final data = myDealsFromJson(<String, dynamic>{
      'country': 'SA',
      'deals': <Object?>[
        <String, dynamic>{
          'store': 'كارفور',
          'item_name': 'زيت عافية 1.5 لتر',
          'price': 18.5,
          'price_before': 25,
          'currency': 'SAR',
          'saving': 26,
          'source_kind': 'youtube',
          'source_url': 'https://www.youtube.com/watch?v=abc123XYZ',
          'valid_until': '2026-11-10T23:59:59Z',
        },
        <String, dynamic>{
          'store': 'كارفور',
          'item_name': 'x',
          'price': 0,
          'source_url': 'https://a',
        },
        <String, dynamic>{
          'store': 'كارفور',
          'item_name': 'رز',
          'price': 9,
          'source_url': 'http://a',
        },
        'junk',
      ],
      'codes': <Object?>[
        <String, dynamic>{
          'store': 'كيتا',
          'code': 'KEETA30',
          'discount_percent': 30,
          'min_order': 50,
          'source_kind': 'instagram',
          'source_url': 'https://www.instagram.com/p/x/',
        },
        <String, dynamic>{
          'store': 'نينجا',
          'code': 'NOOFF',
          'source_url': 'https://x',
        },
      ],
    });
    expect(data.country, 'SA');
    expect(data.deals, hasLength(1));
    expect(data.deals.single.priceBefore, 25);
    expect(data.codes.single.code, 'KEETA30');
    expect(myDealsFromJson(null).deals, isEmpty);
  });

  test(
    'a YouTube deal shows its thumbnail by id; nothing else invents one',
    () {
      expect(
        youtubeThumbnail('https://www.youtube.com/watch?v=abc123XYZ'),
        'https://i.ytimg.com/vi/abc123XYZ/hqdefault.jpg',
      );
      expect(youtubeThumbnail('https://www.instagram.com/p/x/'), isNull);
    },
  );

  test("Amazon's own photo of the same product, never a loose match", () {
    final catalogue = <AffiliateProduct>[
      _product(
        'زيت',
        image: 'https://m.media-amazon.com/oil.jpg',
        keywords: <String>['عافية'],
      ),
      _product('رز'),
    ];
    expect(
      catalogueImage('زيت عافية 1.5 لتر', catalogue),
      'https://m.media-amazon.com/oil.jpg',
    );
    expect(catalogueImage('رز بسمتي', catalogue), isNull);
    expect(catalogueImage('سكر', catalogue), isNull);
  });

  test('sources, money and the last day as the cards write them', () {
    expect(dealSourceOf('youtube'), DealSource.video);
    expect(dealSourceOf('tiktok'), DealSource.video);
    expect(dealSourceOf('instagram'), DealSource.post);
    expect(dealSourceOf('facebook'), DealSource.page);
    expect(dealSourceOf('receipt'), DealSource.receipts);
    expect(dealSourceOf('?'), DealSource.other);
    expect(dealMoney(1250), '1,250');
    expect(dealMoney(18.5), '18.5');
    expect(dealDay(DateTime.utc(2026, 11, 10, 23, 59)), '10/11');
  });
}
