import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/bank/domain/bank_notification.dart';
import 'package:zad/shared/bank/domain/offer_apps.dart';

void main() {
  BankNotificationVerdict read(String package, String text) =>
      classifyBankNotification(title: '', text: text, packageName: package);

  // ZAD_PLAN ١٠.١٤: a shopping app's discount went to the bin as an advert.
  test('a discount or a code from a shopping or delivery app goes to the '
      'server', () {
    for (final (package, text) in <(String, String)>[
      ('com.talabat', 'عرض خاص: خصم 30% على طلبك الجاي بكود PIZZA30'),
      ('com.hungerstation.android', 'توصيل مجاني النهارده بس'),
      ('com.amazon.mShop.android.shopping', 'Deal of the day: 40% off'),
    ]) {
      final v = read(package, text);
      expect(v.classification, BankNotificationClass.offer, reason: text);
      expect(
        shouldSendToBrain(
          classification: v.classification,
          reason: v.reason,
          isTrackedFinancialApp: false,
        ),
        isTrue,
      );
    }
  });

  test('a login code from a shopping app never leaves the phone', () {
    final v = read('com.talabat', 'رمز التحقق 4821 لا تشاركه مع أحد');
    expect(v.classification, isNot(BankNotificationClass.offer));
  });

  test(
    'an advert from a chat, an SMS app or an unknown app is not an offer',
    () {
      for (final package in <String>[
        'com.whatsapp',
        'com.google.android.apps.messaging',
        'com.example.game',
      ]) {
        expect(
          read(package, 'عرض خاص: خصم 30% على كل حاجة').classification,
          isNot(BankNotificationClass.offer),
          reason: package,
        );
      }
      expect(isOfferApp(null), isFalse);
    },
  );

  test('an order update from a delivery app is not an offer', () {
    expect(
      read(
        'com.talabat',
        'طلبك في الطريق، هيوصلك خلال 20 دقيقة',
      ).classification,
      isNot(BankNotificationClass.offer),
    );
  });
}
