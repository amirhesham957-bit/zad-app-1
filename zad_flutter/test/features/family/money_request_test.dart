import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/family/domain/family_life.dart';

void main() {
  group('a child asks for money', () {
    test('an allowance says so and carries its kind', () {
      final r = moneyRequest(what: '', amount: 50, allowance: true);
      expect(r.text, 'محتاج مصروف 50');
      expect(r.metadata, <String, dynamic>{
        'amount': 50.0,
        'status': 'PENDING',
        'kind': 'allowance',
      });
    });

    test('an allowance may give a reason', () {
      final r = moneyRequest(
        what: 'رحلة المدرسة',
        amount: 75.5,
        allowance: true,
      );
      expect(r.text, 'محتاج مصروف 75.50 — رحلة المدرسة');
    });

    test('a purchase names what it is for', () {
      final r = moneyRequest(what: 'لعبة', amount: 100, allowance: false);
      expect(r.text, 'أحتاج 100 لشراء لعبة');
      expect(r.metadata['kind'], 'purchase');
    });
  });

  group('what a child spent', () {
    final since = DateTime.utc(2026, 9, 28);
    FamilyMessage request(Map<String, dynamic> meta, {String from = 'kid'}) =>
        FamilyMessage(
          id: '${meta.hashCode}',
          senderId: from,
          message: '',
          type: FamilyMessageType.purchaseRequest,
          metadata: jsonEncode(meta),
          createdAt: DateTime.utc(2026, 9, 28, 12),
        );

    test('pocket money received is not spending', () {
      final messages = <FamilyMessage>[
        request(<String, dynamic>{
          'amount': 50,
          'status': 'APPROVED',
          'kind': 'allowance',
        }),
        request(<String, dynamic>{
          'amount': 20,
          'status': 'APPROVED',
          'kind': 'purchase',
        }),
        // Kotlin's requests carry no kind; they stay purchases.
        request(<String, dynamic>{'amount': 5, 'status': 'APPROVED'}),
      ];
      expect(approvedSpendSince(messages, 'kid', since), 25);
      expect(messages.first.isAllowanceRequest, isTrue);
      expect(messages.last.isAllowanceRequest, isFalse);
    });
  });
}
