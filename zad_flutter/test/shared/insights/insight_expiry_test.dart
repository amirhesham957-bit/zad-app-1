// A card about a day leaves Home and the bell once that day is over:
// «تجديد نتفليكس بكرة ٣ أكتوبر» was still on Home on 5 October (2026-10-05).

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/insights/domain/insight.dart';

ZadInsight _card(String id, String surface, {String? expiresAt}) =>
    ZadInsight.fromJson(<String, dynamic>{
      'id': id,
      'kind': 'alert',
      'surface': surface,
      'title': 'تجديد نتفليكس بكرة',
      'body': 'اشتراك نتفليكس بـ 300 جنيه هيتجدد بكرة 3 أكتوبر',
      'created_at': '2026-10-02T04:53:08Z',
      'expires_at': ?expiresAt,
    });

void main() {
  final now = DateTime.utc(2026, 10, 5, 9);

  test('an expired card is off Home and the bell; an open-ended one stays', () {
    final cards = <ZadInsight>[
      _card('old', 'home_card', expiresAt: '2026-10-03T21:00:00Z'),
      _card('live', 'home_card', expiresAt: '2026-10-06T21:00:00Z'),
      _card('open', 'home_card'),
      _card('bell-old', 'bell', expiresAt: '2026-10-01T04:53:08Z'),
      _card('bell-open', 'bell'),
    ];
    expect(homeInsights(cards, now: now).map((i) => i.id).toSet(), <String>{
      'live',
      'open',
    });
    expect(bellInsights(cards, now: now).map((i) => i.id), <String>[
      'bell-open',
    ]);
  });

  test('the end survives the cache', () {
    final card = _card('c', 'home_card', expiresAt: '2026-10-03T21:00:00Z');
    final back = ZadInsight.fromJson(card.toJson());
    expect(back.expiresAt, DateTime.utc(2026, 10, 3, 21));
    expect(back.isExpiredAt(now), isTrue);
    expect(back.isExpiredAt(DateTime.utc(2026, 10, 3, 20)), isFalse);
  });
}
