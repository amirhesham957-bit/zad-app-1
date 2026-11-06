// ZAD_PLAN ٢.٨: life-event notifications reach the server; news, chat and
// money messages keep their old path.
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/bank/data/notification_ingest.dart';
import 'package:zad/shared/bank/domain/bank_notification.dart';
import 'package:zad/shared/bank/domain/life_event_hint.dart';
import 'package:zad/shared/insights/domain/insight.dart';

const String _sms = 'com.google.android.apps.messaging';

// l10n: data-begin
const List<String> _lifeEvents = <String>[
  'تم حجز موعدكم في معمل البرج يوم الأحد 8/11 الساعة 10:30 ص',
  'أبشر: تنتهي إقامة أحد التابعين بعد 30 يوم، جددها من https://absher.sa',
  'نتيجة التحليل جاهزة، تقدر تستلمها من الفرع بعد الساعة 4',
  'شحنتك رقم 55 جاهزة للاستلام من فرع المعادي',
  'أبشر: انتهت صلاحية رخصة القيادة 12/10',
  'Your appointment at Saudi German Hospital is confirmed for 9 Nov 10:00',
];

const List<String> _notLifeEvents = <String>[
  'موعد مباراة الأهلي والزمالك الساعة 8 مساءً', // news, no «your»
  'نتيجة المباراة 2-1', // sports
  'موعدك اليوم مع الدكتور', // no date, time or link
  'رمز التحقق 4455 لموعدك', // OTP stays OTP
];
// l10n: data-end

void main() {
  test('appointments, Absher, results and parcels are life events', () {
    for (final t in _lifeEvents) {
      expect(looksLikeLifeEvent(t, packageName: _sms), isTrue, reason: t);
      final v = classifyBankNotification(title: '', text: t, packageName: _sms);
      expect(v.classification, BankNotificationClass.lifeEvent, reason: t);
      expect(
        shouldSendToBrain(
          classification: v.classification,
          reason: v.reason,
          isTrackedFinancialApp: false,
        ),
        isTrue,
        reason: t,
      );
    }
  });

  test('news, bare words, OTPs and chat apps are not', () {
    for (final t in _notLifeEvents) {
      final v = classifyBankNotification(title: '', text: t, packageName: _sms);
      expect(
        v.classification,
        isNot(BankNotificationClass.lifeEvent),
        reason: t,
      );
    }
    expect(
      looksLikeLifeEvent(_lifeEvents.first, packageName: 'com.whatsapp'),
      isFalse,
    );
  });

  test('a fine with an amount stays a money question for the server', () {
    final v = classifyBankNotification(
      title: '',
      text: 'لديك مخالفة مرورية بمبلغ 300 ريال', // l10n: data
      packageName: _sms,
    );
    expect(v.classification, BankNotificationClass.ambiguous);
  });

  test('the wire name the server reads', () {
    final payload = buildNotificationIngestPayload(
      userId: 'u',
      packageName: _sms,
      title: '',
      text: _lifeEvents.first,
      verdict: const BankNotificationVerdict(
        classification: BankNotificationClass.lifeEvent,
      ),
    );
    expect(payload['client_classification'], 'life_event');
    expect(payload['parsed'], isEmpty);
  });

  test('a life event card is told apart by its about_item', () {
    const id = '0f8fad5b-d9cb-469f-a165-70867728950e';
    expect(
      lifeEventIdOf(
        const ZadInsight(
          id: 'i',
          title: 't',
          body: 'b',
          aboutItem: 'life_event:$id',
        ),
      ),
      id,
    );
    expect(
      lifeEventIdOf(
        const ZadInsight(
          id: 'i',
          title: 't',
          body: 'b',
          aboutItem: 'لبن',
        ), // l10n: data
      ),
      isNull,
    );
  });
}
