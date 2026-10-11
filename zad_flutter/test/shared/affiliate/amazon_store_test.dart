// Egypt shops amazon.eg with its own associate tag; every other country
// amazon.sa with the Saudi one (owner, 2026-10-10). A tag registered on one
// store earns nothing on another, so store and tag always travel together.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/affiliate/domain/affiliate.dart';

void main() {
  AffiliateProduct product({String? asin, bool verified = true}) => (
    id: 'p1',
    nameAr: 'حليب',
    asin: asin,
    asinVerified: verified,
    imageUrl: null,
    averagePriceSar: 0,
    isActive: true,
    keywords: const <String>[],
    priceCheckedAt: null,
  );

  test('Egypt: amazon.eg with zad04-21', () {
    expect(amazonStoreFor('EG'), 'www.amazon.eg');
    expect(amazonStoreFor(' eg '), 'www.amazon.eg');
    expect(amazonTagFor('EG'), 'zad04-21');
    expect(
      affiliateUrl(product(asin: 'B0ABCDEF12'), 'EG'),
      'https://www.amazon.eg/dp/B0ABCDEF12?tag=zad04-21',
    );
  });

  test('every other country: amazon.sa with the Saudi tag', () {
    for (final cc in <String?>['SA', 'AE', 'KW', 'TR', null, '']) {
      expect(amazonStoreFor(cc), 'www.amazon.sa', reason: '$cc');
      expect(amazonTagFor(cc), 'zad0b-21', reason: '$cc');
    }
    expect(
      affiliateUrl(product(asin: 'B0ABCDEF12'), 'AE'),
      'https://www.amazon.sa/dp/B0ABCDEF12?tag=zad0b-21',
    );
  });

  test('an unverified code opens a search in the same store', () {
    expect(
      affiliateUrl(product(asin: 'B0ABCDEF12', verified: false), 'EG'),
      startsWith('https://www.amazon.eg/s?k='),
    );
    expect(
      affiliateUrl(product(asin: 'B0ABCDEF12', verified: false), 'EG'),
      endsWith('&tag=zad04-21'),
    );
  });

  test('a «حاجة خلصت» message splits into its text and its Amazon links', () {
    const eg = 'https://www.amazon.eg/s?k=x&tag=zad04-21';
    const sa = 'https://www.amazon.sa/s?k=y&tag=zad0b-21';
    final split = splitAmazonLinks(
      'خلصوا عندك: حليب، قهوة. جهزتلك لينكات.\n• حليب: $eg\n• قهوة: $sa',
    );
    expect(split.text, 'خلصوا عندك: حليب، قهوة. جهزتلك لينكات.');
    expect(split.links, <AmazonLink>[
      (name: 'حليب', url: eg),
      (name: 'قهوة', url: sa),
    ]);
    // Anything that is not an Amazon store stays text, untouched.
    const other =
        '• خريطة: https://evil.example/x\n• حليب: http://www.amazon.eg/s';
    expect(splitAmazonLinks(other).links, isEmpty);
    expect(splitAmazonLinks(other).text, other);
    expect(splitAmazonLinks('رسالة عادية').links, isEmpty);
  });
}
