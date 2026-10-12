// Emptying the capture inbox.
//
// The native service cannot run here, so the listener is faked at the package
// boundary. What is being tested is the part that decides — and the two
// properties that keep a bank message from being lost: nothing is acknowledged
// before it has been dealt with, and nothing is queued for nobody.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/sync/outbox.dart';
import 'package:zad/core/data/sync/outbox_entry.dart';
import 'package:zad/features/bank/data/background_delivery.dart';
import 'package:zad/shared/bank/data/bank_rejected_log.dart';
import 'package:zad/shared/bank/data/notification_drain.dart';
import 'package:zad/shared/bank/domain/bank_notification.dart';
import 'package:zad/shared/bank/domain/tracked_financial_apps.dart';
import 'package:zad_bank_listener/zad_bank_listener.dart';

/// Stands in for the Android service's inbox.
class _FakeListener implements ZadBankListener {
  new(this.rows);

  List<CapturedNotification> rows;
  final List<int> acknowledged = <int>[];
  int peeks = 0;

  @override
  Future<List<CapturedNotification>> peek({int limit = 100}) async {
    peeks++;
    return rows.take(limit).toList();
  }

  @override
  Future<void> acknowledge(Iterable<int> ids) async {
    acknowledged.addAll(ids);
    rows = rows.where((r) => !ids.contains(r.id)).toList();
  }

  @override
  Future<int> pendingCount() async => rows.length;

  /// What the background engine parked while the app was closed.
  List<ParkedRejection> parked = <ParkedRejection>[];

  @override
  Future<void> recordRejected({
    required String source,
    required String reason,
    required String rawText,
    required DateTime at,
  }) async => parked.add(
    ParkedRejection(source: source, reason: reason, rawText: rawText, at: at),
  );

  @override
  Future<List<ParkedRejection>> takeRejected() async {
    final out = parked;
    parked = <ParkedRejection>[];
    return out;
  }

  @override
  Future<List<({bool on, DateTime at})>> screenEvents() async =>
      const <({bool on, DateTime at})>[];

  @override
  Future<void> setScreenEventsEnabled({required bool enabled}) async {}

  @override
  Future<ListenerStatus> listenerStatus() async => const ListenerStatus();

  @override
  Future<void> sendTestNotification({
    required String title,
    required String body,
  }) async {}

  @override
  Future<bool> isPermissionGranted() async => true;

  @override
  Future<InstallInfo> installInfo() async => const InstallInfo(sdk: 34);

  @override
  Future<void> openAppDetails() async {}

  @override
  Future<void> openPermissionSettings() async {}

  @override
  Future<bool> requestRebind() async => true;

  @override
  Future<void> registerBackgroundHandle(int handle) async {}

  @override
  Future<void> backgroundDone() async {}

  @override
  Stream<void> get captures => const Stream<void>.empty();
}

CapturedNotification _n(
  int id,
  String text, {
  String pkg = 'com.google.android.apps.messaging',
  String title = 'بنك',
}) => CapturedNotification(
  id: id,
  packageName: pkg,
  title: title,
  text: text,
  postedAt: DateTime.utc(2026, 9, 20, 12),
);

void main() {
  late Directory dir;
  late Box<String> box;
  late Outbox outbox;
  var nextId = 0;
  String? signedIn = 'user-1';

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_drain_test');
    Hive.init(dir.path);
    box = await Hive.openBox<String>('outbox');
    nextId = 0;
    signedIn = 'user-1';
    outbox = Outbox(
      box: box,
      send: (e) async {},
      clock: () => DateTime.utc(2026, 9, 20, 12),
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  NotificationDrain drainOver(_FakeListener listener) => NotificationDrain(
    listener: listener,
    outbox: outbox,
    newId: () => 'ingest-${++nextId}',
    signedInUserId: () => signedIn,
    isTrackedFinancialApp: isTrackedFinancialApp,
    marketCurrency: () => 'SAR',
  );

  test('the messaging app is the channel, and it is untracked', () async {
    // Measured: every recorded bank transaction on this project came from this
    // package, and it is not in the tracked list. A drain that only queued
    // tracked packages would queue none of them.
    expect(isTrackedFinancialApp('com.google.android.apps.messaging'), isFalse);

    final listener = _FakeListener(<CapturedNotification>[
      _n(1, 'تم خصم 50 ر.س من حسابك لدى بنده'),
    ]);

    final report = await drainOver(listener).drain();

    expect(report.seen, 1);
    expect(report.queued, 1);
    expect(outbox.entries().single.kind, OutboxKind.notificationIngest);
  });

  test('noise is taken out of the inbox and not queued', () async {
    final listener = _FakeListener(<CapturedNotification>[
      _n(1, 'رمز التحقق الخاص بك هو 4521 لا تشاركه مع أحد'),
      _n(2, 'عرض خاص! خصم يصل الى 20%'),
      _n(3, 'وصلتك 3 رسائل جديدة'),
    ]);

    final report = await drainOver(listener).drain();

    expect(report.seen, 3);
    expect(report.queued, 0, reason: 'noise reached the server');
    // Still acknowledged: leaving them would re-judge the same rubbish forever.
    expect(listener.acknowledged, <int>[1, 2, 3]);
    expect(outbox.entries(), isEmpty);
  });

  test(
    'a mixed batch queues only what matters, and clears all of it',
    () async {
      final listener = _FakeListener(<CapturedNotification>[
        _n(1, 'رمز التحقق 4521'),
        _n(2, 'تم خصم 125.50 ر.س من حسابك'),
        _n(3, 'تم تحديث بيانات حسابك بنجاح'),
        _n(4, 'تم خصم 70 ر.س من حسابك'),
      ]);

      final report = await drainOver(listener).drain();

      expect(report.seen, 4);
      expect(report.queued, 2);
      expect(listener.acknowledged, <int>[1, 2, 3, 4]);
    },
  );

  test('nothing is queued, or acknowledged, for nobody', () async {
    // The payload carries a user_id. Queueing writes that name no one just
    // manufactures dead letters.
    signedIn = null;
    final listener = _FakeListener(<CapturedNotification>[
      _n(1, 'تم خصم 50 ر.س من حسابك'),
    ]);

    final report = await drainOver(listener).drain();

    expect(report.seen, 0);
    expect(report.queued, 0);
    expect(listener.peeks, 0, reason: 'the inbox was read with no user');
    expect(listener.acknowledged, isEmpty);
    // The notification is still there for when somebody signs in.
    expect(await listener.pendingCount(), 1);
  });

  test('an unreadable message from a named bank app still goes up', () async {
    final listener = _FakeListener(<CapturedNotification>[
      _n(1, 'تم تحديث بيانات حسابك بنجاح', pkg: 'com.alrajhibank.activity'),
    ]);

    final report = await drainOver(listener).drain();

    expect(report.queued, 1);
  });

  test('draining twice does not double-queue', () async {
    final listener = _FakeListener(<CapturedNotification>[
      _n(1, 'تم خصم 50 ر.س من حسابك'),
    ]);
    final drain = drainOver(listener);

    await drain.drain();
    final second = await drain.drain();

    expect(second.seen, 0);
    expect(outbox.entries(), hasLength(1));
  });

  group('rejected while the app was closed', () {
    // The background engine must not open Hive, so it parks rejections in the
    // native store and the next drain moves them into the log.

    test(
      'the drain moves them into the log, with when they happened',
      () async {
        final log = BankRejectedLog(await Hive.openBox<String>('documents'));
        final listener = _FakeListener(<CapturedNotification>[]);
        final whileClosed = DateTime.utc(2026, 9, 20, 3, 15);

        // The background run, with the wiring bankBackgroundMain gives it.
        await BackgroundBankDelivery(
          peek: (limit) => listener.peek(limit: limit),
          acknowledge: listener.acknowledge,
          send: (_) async => null,
          userId: 'user-1',
          isTrackedFinancialApp: isTrackedFinancialApp,
          onRejected: (source, reason, rawText) => listener.recordRejected(
            source: source,
            reason: reason.name,
            rawText: rawText,
            at: whileClosed,
          ),
        ).run();
        expect(
          listener.parked,
          isEmpty,
          reason: 'nothing was in the inbox yet',
        );

        listener.rows = <CapturedNotification>[
          _n(1, 'رمز التحقق الخاص بك هو 4521 لا تشاركه مع أحد', title: 'CIB'),
        ];
        await BackgroundBankDelivery(
          peek: (limit) => listener.peek(limit: limit),
          acknowledge: listener.acknowledge,
          send: (_) async => null,
          userId: 'user-1',
          isTrackedFinancialApp: isTrackedFinancialApp,
          onRejected: (source, reason, rawText) => listener.recordRejected(
            source: source,
            reason: reason.name,
            rawText: rawText,
            at: whileClosed,
          ),
        ).run();
        expect(listener.parked, hasLength(1));
        expect(log.read(), isEmpty, reason: 'the background wrote to Hive');

        // The app opens and drains.
        await NotificationDrain(
          listener: listener,
          outbox: outbox,
          newId: () => 'ingest-${++nextId}',
          signedInUserId: () => signedIn,
          isTrackedFinancialApp: isTrackedFinancialApp,
          onRejected: (source, reason, raw, at) =>
              log.add(source, reason, raw, at: at),
        ).drain();
        await Future<void>.delayed(Duration.zero);

        final entry = log.read().single;
        expect(entry.reason, 'OTP');
        expect(entry.source, 'CIB');
        expect(entry.createdAt, whileClosed);
        expect(listener.parked, isEmpty, reason: 'taken, so not logged twice');
      },
    );

    test('a reason this build does not know is skipped, not a crash', () async {
      final listener = _FakeListener(<CapturedNotification>[])
        ..parked = <ParkedRejection>[
          ParkedRejection(
            source: 'x',
            reason: 'renamed_in_a_later_build',
            rawText: 'x',
            at: DateTime.utc(2026),
          ),
          ParkedRejection(
            source: 'بنك',
            reason: BankRejectReason.promo.name,
            rawText: 'عرض خاص',
            at: DateTime.utc(2026),
          ),
        ];
      final got = <BankRejectReason>[];

      await NotificationDrain(
        listener: listener,
        outbox: outbox,
        newId: () => 'ingest-${++nextId}',
        signedInUserId: () => signedIn,
        isTrackedFinancialApp: isTrackedFinancialApp,
        onRejected: (_, reason, _, _) => got.add(reason),
      ).drain();

      expect(got, <BankRejectReason>[BankRejectReason.promo]);
    });
  });

  test('a rejection while the app is open is logged at now', () async {
    final listener = _FakeListener(<CapturedNotification>[
      _n(1, 'رمز التحقق 4521'),
    ]);
    final times = <DateTime?>[];

    await NotificationDrain(
      listener: listener,
      outbox: outbox,
      newId: () => 'ingest-${++nextId}',
      signedInUserId: () => signedIn,
      isTrackedFinancialApp: isTrackedFinancialApp,
      onRejected: (_, _, _, at) => times.add(at),
    ).drain();

    expect(times, <DateTime?>[null]);
  });
}
