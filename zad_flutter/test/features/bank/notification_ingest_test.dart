// The path from a raw notification to a queued entry.
//
// The rule this pins is the one the server-first rewrite exists for: this
// client never writes a transaction. It hears, it decides, it queues. A debit
// appearing on someone's card without them agreeing to it is the failure mode
// being designed out.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/bank/data/notification_ingest.dart';

void main() {
  late Directory dir;
  late Box<String> box;
  late Outbox outbox;
  var nextId = 0;
  final now = DateTime.parse('2026-09-20T12:00:00Z');

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_ingest_test');
    Hive.init(dir.path);
    box = await Hive.openBox<String>('outbox');
    nextId = 0;
    outbox = Outbox(box: box, send: (e) async {}, clock: () => now);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  Future<OutboxEntry?> ingest({
    required String text,
    String title = 'بنك',
    String packageName = 'com.google.android.apps.messaging',
    bool tracked = false,
    String? market,
  }) => ingestBankNotification(
    outbox: outbox,
    newId: () => 'ingest-${++nextId}',
    userId: 'user-1',
    packageName: packageName,
    title: title,
    text: text,
    isTrackedFinancialApp: tracked,
    marketCurrency: market,
  );

  group('what reaches the queue', () {
    test('a readable debit is queued, not written', () async {
      final entry = await ingest(
        text: 'تم خصم بمبلغ 125.50 ريال من حسابك في متجر بنده',
        market: 'SAR',
      );

      expect(entry, isNotNull);
      expect(entry!.kind, OutboxKind.notificationIngest);
      expect(entry.payload['action'], 'notification_ingest');
      expect(entry.payload['client_classification'], 'ambiguous');

      final parsed = entry.payload['parsed']! as Map<String, dynamic>;
      expect(parsed['amount'], closeTo(125.50, 0.001));
      expect(parsed['currency'], 'SAR');
      // Never claimed as settled: the server compares this against 0.9 and asks
      // the customer.
      expect(parsed['confidence'], 0.0);
    });

    test(
      'the message arrives from the messaging app, which is untracked',
      () async {
        // Measured on this project: every recorded bank transaction arrived
        // through an untracked package, and all of them from the messaging app.
        // A gate that only let tracked apps through would pass none of them.
        // The default packageName in `ingest` is the messaging app, which is
        // the point: it is not in trackedPackages and never will be.
        expect(await ingest(text: 'تم خصم 50 ر.س من حسابك'), isNotNull);
      },
    );

    test('a conditional renewal is queued as failed or pending', () async {
      final entry = await ingest(
        text:
            'لا يوجد رصيد كافي لتجديد خدمة DSL بقيمة 530.1 ج.م. '
            'سيتم تجديد الخدمة تلقائياً في حالة وجود رصيد كافي',
      );

      expect(entry, isNotNull);
      expect(
        entry!.payload['client_classification'],
        'failed_or_pending_transaction',
      );
      // No amount is offered for a charge that has not happened.
      expect(entry.payload['parsed'], isEmpty);
    });
  });

  group('what does not', () {
    test('an OTP is dropped', () async {
      expect(
        await ingest(text: 'رمز التحقق الخاص بك هو 4521 لا تشاركه مع أحد'),
        isNull,
      );
      expect(outbox.entries(), isEmpty);
    });

    test('an advert is dropped', () async {
      expect(await ingest(text: 'عرض خاص! خصم يصل الى 20%'), isNull);
    });

    test('an ordinary message with a number in it is dropped', () async {
      // "رس" sits inside "رسائل". Without the right word boundary this reads as
      // a 3-unit transaction — from the messaging app, which is the primary
      // bank channel.
      expect(await ingest(text: 'وصلتك 3 رسائل جديدة'), isNull);
      expect(outbox.entries(), isEmpty);
    });

    test(
      'unreadable: dropped from an unknown app, sent from a bank app',
      () async {
        const text = 'تم تحديث بيانات حسابك بنجاح';
        expect(await ingest(text: text), isNull);
        expect(await ingest(text: text, tracked: true), isNotNull);
      },
    );
  });

  group('the queue keeps its guarantees', () {
    test(
      'each ingest has its own id, so a replay cannot double-ingest',
      () async {
        await ingest(text: 'تم خصم 50 ر.س من حسابك');
        await ingest(text: 'تم خصم 70 ر.س من حسابك');

        final ids = outbox.entries().map((e) => e.id).toSet();
        expect(ids, hasLength(2));
      },
    );

    test('a queued notification survives the app being killed', () async {
      await ingest(text: 'تم خصم 50 ر.س من حسابك', market: 'SAR');
      await box.close();

      final reopened = await Hive.openBox<String>('outbox');
      final after = Outbox(box: reopened, send: (e) async {}, clock: () => now);

      final entry = after.entries().single;
      expect(entry.kind, OutboxKind.notificationIngest);
      expect(entry.payload['text'], contains('50'));
    });

    test(
      'the payload is plain JSON, as the box and the wire both need',
      () async {
        await ingest(text: 'تم خصم 50 ر.س من حسابك', market: 'SAR');
        final raw = box.values.single;
        expect(() => jsonDecode(raw), returnsNormally);
      },
    );
  });
}
