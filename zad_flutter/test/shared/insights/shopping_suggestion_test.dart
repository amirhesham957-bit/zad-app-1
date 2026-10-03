// A family-chat need the nightly review found is a line in the brief, not a
// home card of its own.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/insights/domain/insight.dart';

void main() {
  test('home cards leave family needs to the brief', () {
    final need = ZadInsight.fromJson(const <String, dynamic>{
      'id': 'n',
      'kind': 'insight',
      'surface': 'home_card',
      'title': 'عيش',
      'body': 'ماما قال في شات العيلة إنه ناقص',
      'about_item': 'عيش',
      'action_type': kShoppingAddAction,
    });
    final card = ZadInsight.fromJson(const <String, dynamic>{
      'id': 'c',
      'kind': 'insight',
      'surface': 'home_card',
      'title': 'صرفك على المطاعم زاد',
      'body': '…',
    });
    expect(need.isShoppingSuggestion, isTrue);
    expect(homeInsights(<ZadInsight>[need, card]).map((i) => i.id), <String>[
      'c',
    ]);
  });
}
