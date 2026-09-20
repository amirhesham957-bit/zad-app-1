// Parity with SaBankParserTest.kt.
//
// Every vector below is copied verbatim from the Kotlin test — the same
// message strings, the same expected answers. That is the whole point: the
// notification gate now exists twice, and the thing that makes two
// implementations of one rule safe is a test that fails the moment they part
// company. If one of these fails, the Kotlin is right and the Dart is what
// needs changing.
//
// The message strings are matching data, not UI text. Translating one does not
// fail a build; it makes a real customer's bank message stop being read.

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/bank/domain/bank_notification.dart';

void main() {
  group('the message that started it', () {
    test('a renewal conditional on a balance is never a transaction', () {
      // The real Vodafone message that was recorded as a 530.1 EGP debit: it
      // carries no declined keyword, so it passed the noise filter, while the
      // text says outright that the charge is conditional and has not happened.
      final verdict = classifyBankNotification(
        title: 'Vodafone',
        text:
            'لا يوجد رصيد كافي لتجديد خدمة DSL بقيمة 530.1 ج.م. '
            'سيتم تجديد الخدمة تلقائياً في حالة وجود رصيد كافي',
      );

      expect(
        verdict.classification,
        BankNotificationClass.failedOrPendingTransaction,
      );
      expect(verdict.reason, BankRejectReason.pending);
    });
  });

  group('extractAmount', () {
    test('picks the labelled amount over the balance', () {
      expect(
        extractAmount(
          'مصرف الراجحي: تم خصم بمبلغ 125.50 ريال من حسابك في متجر بنده. '
          'الرصيد المتاح: 3,450.00 ريال',
        ),
        closeTo(125.50, 0.001),
      );
    });

    test('excludes a number in balance context', () {
      expect(
        extractAmount('خصم 30 ريال من حسابك. الرصيد المتاح: 970 ريال'),
        closeTo(30, 0.001),
      );
    });

    test('normalises Arabic-Indic digits', () {
      expect(
        extractAmount('خصم ١٢٥.٥٠ ريال من بطاقتك'),
        closeTo(125.50, 0.001),
      );
    });

    test('handles a thousands separator', () {
      expect(
        extractAmount(
          'مصرف الإنماء: تم إيداع راتب بمبلغ 8,500.00 ريال في حسابك. '
          'الرصيد الحالي: 12,300.00 ريال',
        ),
        closeTo(8500, 0.001),
      );
    });

    test('is null when there is no amount', () {
      expect(
        extractAmount('رمز التحقق الخاص بك هو 4521 لا تشاركه مع أحد'),
        isNull,
      );
    });

    test('excludes masked card digits sitting next to a currency', () {
      expect(
        extractAmount('بطاقتك *1234 SAR 500.00 تم الخصم'),
        closeTo(500, 0.001),
      );
    });

    test('excludes "card ending" digits in English', () {
      expect(
        extractAmount('Your card ending 1234 SAR 75.00 was charged'),
        closeTo(75, 0.001),
      );
    });
  });

  group('extractCurrency', () {
    test('reads SAR from a Saudi riyal message', () {
      expect(
        extractCurrency(
          'مصرف الراجحي: تم خصم بمبلغ 125.50 ريال من حسابك في متجر بنده',
          marketCurrency: 'SAR',
        ),
        'SAR',
      );
    });

    test('reads EGP from an Egyptian pound message', () {
      expect(
        extractCurrency('تم خصم مبلغ 300 ج.م من حسابك لدى بنك مصر'),
        'EGP',
      );
    });

    test('reads TRY from a Turkish lira message', () {
      expect(
        extractCurrency('kartınızdan 150,00 TL tutarında harcama yapıldı'),
        'TRY',
      );
    });

    test('is null when no currency token appears', () {
      expect(extractCurrency('خصم 30 من حسابك اليوم'), isNull);
    });

    test('reads a local abbreviation whatever market is active', () {
      expect(
        extractCurrency('تم خصم 200 د.إ من بطاقتك', marketCurrency: 'SAR'),
        'AED',
      );
    });

    test('resolves an ambiguous word using the active market', () {
      expect(
        extractCurrency('تم خصم 15 دينار من حسابك', marketCurrency: 'KWD'),
        'KWD',
      );
    });

    test('refuses to guess an ambiguous word across a border', () {
      // "دينار" is Kuwaiti, Bahraini, Jordanian, Iraqi, Libyan, Tunisian or
      // Algerian. Refusing beats guessing — the caller falls back to the
      // account's own currency.
      expect(
        extractCurrency('تم خصم 15 دينار من حسابك', marketCurrency: 'SAR'),
        isNull,
      );
    });
  });

  group('rejectionReason', () {
    test('classifies each noise category', () {
      expect(
        bankRejectionReason('رمز التحقق الخاص بك هو 4521'),
        BankRejectReason.otp,
      );
      expect(
        bankRejectionReason('لا تشارك كلمة المرور مع أحد'),
        BankRejectReason.otp,
      );
      expect(
        bankRejectionReason('العملية لم تتم بسبب رصيد غير كاف'),
        BankRejectReason.declined,
      );
      expect(
        bankRejectionReason('بطاقتك انتهت صلاحيتها'),
        BankRejectReason.expired,
      );
      expect(
        bankRejectionReason('عرض خاص! خصم يصل الى 20%'),
        BankRejectReason.promo,
      );
      expect(bankRejectionReason('تم خصم 50 ريال من حسابك لدى بنده'), isNull);
    });
  });

  group('mentionsMoney', () {
    test('a currency token inside an ordinary word is not money', () {
      // The measured ones. "رس" sits inside "رسائل", and this is the text of a
      // messaging-app notification — which is the primary bank channel on this
      // project, not a fringe case.
      expect(mentionsMoney('وصلتك 3 رسائل جديدة'), isFalse);
      expect(mentionsMoney('Retry 250'), isFalse);
      expect(mentionsMoney('Details 250'), isFalse);
      expect(mentionsMoney('Country 120'), isFalse);
    });

    test('a real currency token is money', () {
      expect(mentionsMoney('تم خصم 50 ر.س'), isTrue);
      expect(mentionsMoney('kartınızdan 150,00 TL'), isTrue);
    });

    test('an Arabic prefix on a currency word still counts', () {
      // Arabic glues prefixes on, so the token is bounded on the right only.
      expect(mentionsMoney('المبلغ بالريال السعودي'), isTrue);
    });
  });

  group('the gate', () {
    test('anything ambiguous goes to the server', () {
      // The messages that most need intelligence are exactly the ones the
      // local parser cannot read. Keeping them back was what left them in a
      // local outbox forever.
      expect(
        shouldSendToBrain(
          classification: BankNotificationClass.ambiguous,
          reason: null,
          isTrackedFinancialApp: false,
        ),
        isTrue,
      );
    });

    test('a failed or pending transaction goes too', () {
      expect(
        shouldSendToBrain(
          classification: BankNotificationClass.failedOrPendingTransaction,
          reason: BankRejectReason.pending,
          isTrackedFinancialApp: false,
        ),
        isTrue,
      );
    });

    test('noise from an unknown app does not', () {
      expect(
        shouldSendToBrain(
          classification: BankNotificationClass.informationalOnly,
          reason: BankRejectReason.promo,
          isTrackedFinancialApp: true,
        ),
        isFalse,
      );
    });

    test('an unreadable message from a named banking app does', () {
      expect(
        shouldSendToBrain(
          classification: BankNotificationClass.informationalOnly,
          reason: null,
          isTrackedFinancialApp: true,
        ),
        isTrue,
      );
      expect(
        shouldSendToBrain(
          classification: BankNotificationClass.informationalOnly,
          reason: null,
          isTrackedFinancialApp: false,
        ),
        isFalse,
      );
    });
  });

  group('classification', () {
    test('an OTP is informational, never a transaction', () {
      final verdict = classifyBankNotification(
        title: 'بنك',
        text: 'رمز التحقق الخاص بك هو 4521 لا تشاركه مع أحد',
      );
      expect(verdict.classification, BankNotificationClass.informationalOnly);
      expect(verdict.reason, BankRejectReason.otp);
      expect(verdict.amount, isNull);
    });

    test('a readable amount is ambiguous, for the server to settle', () {
      // This client never returns completedTransaction: the local parse is a
      // hint, and the server compares its confidence against 0.9.
      final verdict = classifyBankNotification(
        title: 'مصرف الراجحي',
        text: 'تم خصم بمبلغ 125.50 ريال من حسابك في متجر بنده',
        marketCurrency: 'SAR',
      );
      expect(verdict.classification, BankNotificationClass.ambiguous);
      expect(verdict.amount, closeTo(125.50, 0.001));
      expect(verdict.currency, 'SAR');
      expect(
        verdict.classification,
        isNot(BankNotificationClass.completedTransaction),
      );
    });

    test('financial-looking with no amount is informational', () {
      final verdict = classifyBankNotification(
        title: 'بنك',
        text: 'تم تحديث بيانات حسابك بنجاح',
      );
      expect(verdict.classification, BankNotificationClass.informationalOnly);
      expect(verdict.amount, isNull);
    });
  });
}
