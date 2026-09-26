import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/features/bank/data/background_delivery.dart';
import 'package:zad_bank_listener/zad_bank_listener.dart';

CapturedNotification _n(int id, String pkg, String title, String text) =>
    CapturedNotification(
      id: id,
      packageName: pkg,
      title: title,
      text: text,
      postedAt: DateTime.utc(2026, 9, 25),
    );

const String _sms = 'com.google.android.apps.messaging';

// The real BDC message that reached the server on 2026-08-27, word for word.
final CapturedNotification _bdc = _n(
  1,
  _sms,
  'BDC',
  'تم قيد معاملة مشتريات ب 74.00 EGP من PAYMOB-*SFM for m علي بطاقة رقم  '
      '9766 في 27/08 21:21 ورصيدكم الحالي 7260.56',
);
final CapturedNotification _otp = _n(
  2,
  _sms,
  'CIB',
  'كود التحقق الخاص بك هو 482913 لا تشاركه مع أحد',
);
final CapturedNotification _chat = _n(3, _sms, 'أحمد', 'تعالى بكرة');

class _Inbox {
  new(this.rows);

  final List<CapturedNotification> rows;
  final List<int> acked = <int>[];

  Future<List<CapturedNotification>> peek(int limit) async =>
      rows.where((r) => !acked.contains(r.id)).take(limit).toList();

  Future<void> acknowledge(Iterable<int> ids) async => acked.addAll(ids);
}

void main() {
  test('a bank message goes to the server, noise is dropped', () async {
    final inbox = _Inbox([_bdc, _otp, _chat]);
    final sent = <Map<String, dynamic>>[];
    final report = await BackgroundBankDelivery(
      peek: inbox.peek,
      acknowledge: inbox.acknowledge,
      send: (p) async {
        sent.add(p);
        return 'awaiting_confirmation';
      },
      userId: 'u1',
      isTrackedFinancialApp: (_) => false,
    ).run();

    expect(sent, hasLength(1));
    expect(sent.single['action'], 'notification_ingest');
    expect(sent.single['user_id'], 'u1');
    expect(sent.single['package_name'], _sms);
    expect((sent.single['parsed'] as Map)['amount'], 74.0);
    expect(report.sent, 1);
    expect(report.dropped, 2);
    expect(report.stoppedEarly, isFalse);
    expect(inbox.acked, containsAll(<int>[1, 2, 3]));
  });

  test('a transport failure leaves the rest in the inbox', () async {
    final second = _n(
      4,
      _sms,
      'BDC',
      'تم قيد معاملة مشتريات ب 55.45 EGP من BIM STORES LLC',
    );
    final inbox = _Inbox([_bdc, second]);
    final report = await BackgroundBankDelivery(
      peek: inbox.peek,
      acknowledge: inbox.acknowledge,
      send: (_) async => throw Exception('socket closed'),
      userId: 'u1',
      isTrackedFinancialApp: (_) => false,
    ).run();

    expect(report.stoppedEarly, isTrue);
    expect(report.sent, 0);
    // Nothing acknowledged: the app's own drain picks both up later.
    expect(inbox.acked, isEmpty);
  });

  test(
    'a message the server refuses for good does not block the inbox',
    () async {
      final inbox = _Inbox([_bdc]);
      final report = await BackgroundBankDelivery(
        peek: inbox.peek,
        acknowledge: inbox.acknowledge,
        send: (_) async =>
            throw const FunctionException(status: 400, details: 'empty'),
        userId: 'u1',
        isTrackedFinancialApp: (_) => false,
      ).run();

      expect(report.stoppedEarly, isFalse);
      expect(report.dropped, 1);
      expect(inbox.acked, [1]);
    },
  );

  test('auth, timeout and rate-limit failures are retried, not dropped', () {
    for (final status in [401, 408, 429, 500, 503]) {
      expect(
        isPermanentIngestFailure(FunctionException(status: status)),
        isFalse,
        reason: '$status',
      );
    }
    expect(
      isPermanentIngestFailure(const FunctionException(status: 404)),
      isTrue,
    );
    expect(isPermanentIngestFailure(Exception('x')), isFalse);
  });

  test('a long backlog is bounded to maxRounds batches', () async {
    final rows = [
      for (var i = 0; i < 30; i++)
        _n(
          i,
          _sms,
          'BDC',
          'تم قيد معاملة مشتريات ب ${10 + i}.00 EGP من SHOP $i',
        ),
    ];
    final inbox = _Inbox(rows);
    var calls = 0;
    final report = await BackgroundBankDelivery(
      peek: inbox.peek,
      acknowledge: inbox.acknowledge,
      send: (_) async {
        calls++;
        return 'awaiting_confirmation';
      },
      userId: 'u1',
      isTrackedFinancialApp: (_) => false,
    ).run(batch: 5, maxRounds: 2);

    expect(calls, 10);
    expect(report.sent, 10);
    expect(inbox.acked, hasLength(10));
  });
}
