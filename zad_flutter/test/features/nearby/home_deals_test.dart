import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/nearby/domain/home_deals.dart';

void main() {
  Map<String, Object?> card([Map<String, Object?> o = const {}]) =>
      <String, Object?>{
        'item': 'لبن جهينة 1 لتر', // l10n: data
        'store': 'كارفور', // l10n: data
        'price': 35,
        'price_before': 40,
        'currency': 'EGP',
        'saving': 13,
        'why': 'need',
        'url': 'https://www.youtube.com/watch?v=abc123XYZ',
        'source': 'youtube',
        'photo': 'https://i.ytimg.com/vi/abc123XYZ/hqdefault.jpg',
        'code': <String, Object?>{'code': 'SAVE10', 'percent': 10},
        ...o,
      };

  test('a card reads with its picture, saving and its store code', () {
    final deals = homeDealsFromJson(<String, Object?>{
      'ok': true,
      'cards': <Object?>[card()],
    });
    expect(deals, hasLength(1));
    final d = deals.single;
    expect(d.why, HomeDealWhy.need);
    expect(d.priceBefore, 40);
    expect(d.saving, 13);
    expect(d.photo, startsWith('https://i.ytimg.com/'));
    expect(d.code?.code, 'SAVE10');
    expect(d.code?.percent, 10);
  });

  test('a malformed card is dropped, never shown', () {
    final deals = homeDealsFromJson(<String, Object?>{
      'cards': <Object?>[
        card(<String, Object?>{'price': 0}),
        card(<String, Object?>{'item': ''}),
        card(<String, Object?>{'why': 'ad'}),
        'junk',
      ],
    });
    expect(deals, isEmpty);
    expect(homeDealsFromJson(null), isEmpty);
  });

  test(
    'no https link or picture is kept, a code without a discount is not',
    () {
      final d = homeDealsFromJson(<String, Object?>{
        'cards': <Object?>[
          card(<String, Object?>{
            'url': 'http://example.com',
            'photo': 'javascript:x',
            'price_before': 30,
            'code': <String, Object?>{'code': 'X'},
          }),
        ],
      }).single;
      expect(d.url, isNull);
      expect(d.photo, isNull);
      expect(d.priceBefore, isNull);
      expect(d.code, isNull);
    },
  );
}
