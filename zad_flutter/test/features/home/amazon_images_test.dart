// The Amazon strip shows only Amazon's own product photos — a stock picture
// of something else (children in a desert for «مياه», 2026-09-30) misleads.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/affiliate/domain/affiliate.dart';

void main() {
  test('Amazon-hosted product photos pass', () {
    expect(
      amazonImageOrNull('https://m.media-amazon.com/images/I/71abc.jpg'),
      'https://m.media-amazon.com/images/I/71abc.jpg',
    );
    expect(
      amazonImageOrNull('https://images-na.ssl-images-amazon.com/i/x.jpg'),
      isNotNull,
    );
  });

  test('stock photos, plain http and look-alike hosts do not', () {
    expect(amazonImageOrNull('https://images.pexels.com/photos/1.jpeg'), null);
    expect(amazonImageOrNull('http://m.media-amazon.com/x.jpg'), null);
    expect(amazonImageOrNull('https://evil.com/m.media-amazon.com.jpg'), null);
    expect(amazonImageOrNull(null), null);
  });

  test('the built-in catalogue carries no stock photos', () {
    expect(
      kDefaultAffiliateProducts.map((p) => p.imageUrl),
      everyElement(null),
    );
  });

  test('a catalogue row with a Pexels picture reads as having none', () {
    final p = affiliateFromJson(<String, dynamic>{
      'id': 1,
      'product_name_ar': 'مياه',
      'image_url': 'https://images.pexels.com/photos/1.jpeg',
    });
    expect(p.imageUrl, isNull);
  });
}
