// Reading a notification is the only write here, so what matters is that a
// read sticks: through a refresh that races it, through "mark all" not
// swallowing something the customer never saw, and through a server that did
// not actually flip the flag.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/notifications/data/notifications_remote.dart';
import 'package:zad/features/notifications/data/notifications_repository.dart';
import 'package:zad/features/notifications/presentation/notification_center_screen.dart';

class _Remote implements NotificationsRemote {
  final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  bool offline = false;

  /// When true, updates answer without changing anything — the 200 that did
  /// nothing.
  bool ignoresUpdates = false;

  Map<String, dynamic> row(String id, String at, {bool? read = false}) {
    final r = <String, dynamic>{
      'id': id,
      'title': 't$id',
      'message': 'm$id',
      'created_at': at,
      'is_read': read,
    };
    rows.add(r);
    return r;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchLatest({
    required String userId,
    required int limit,
  }) async {
    if (offline) throw const SocketException('offline');
    final sorted = [...rows]
      ..sort(
        (a, b) =>
            (b['created_at'] as String).compareTo(a['created_at'] as String),
      );
    return sorted.take(limit).map((r) => <String, dynamic>{...r}).toList();
  }

  @override
  Future<Map<String, dynamic>?> markReadReturning(String id) async {
    if (offline) throw const SocketException('offline');
    final r = rows.where((r) => r['id'] == id).firstOrNull;
    if (r == null) return null;
    if (!ignoresUpdates) r['is_read'] = true;
    return <String, dynamic>{'id': id, 'is_read': r['is_read']};
  }

  @override
  Future<void> markAllRead({
    required String userId,
    required DateTime upTo,
  }) async {
    if (offline) throw const SocketException('offline');
    if (ignoresUpdates) return;
    for (final r in rows) {
      if (!DateTime.parse(r['created_at'] as String).isAfter(upTo)) {
        r['is_read'] = true;
      }
    }
  }

  @override
  Future<int> unreadUpTo({
    required String userId,
    required DateTime upTo,
  }) async => rows
      .where(
        (r) =>
            r['is_read'] != true &&
            !DateTime.parse(r['created_at'] as String).isAfter(upTo),
      )
      .length;
}

void main() {
  late Directory dir;
  late Box<String> documents;
  late Box<String> outboxBox;
  late _Remote remote;
  late Outbox outbox;
  late NotificationsRepository repo;
  var run = 0;
  var clock = DateTime.utc(2026, 9, 21, 12);

  setUpAll(tz_data.initializeTimeZones);

  setUp(() async {
    run++;
    clock = DateTime.utc(2026, 9, 21, 12);
    dir = await Directory.systemTemp.createTemp('zad_notif_test');
    Hive.init(dir.path);
    documents = await Hive.openBox<String>('documents$run');
    outboxBox = await Hive.openBox<String>('outbox$run');
    remote = _Remote();
    outbox = Outbox(
      box: outboxBox,
      send: (entry) async => switch (entry.kind) {
        OutboxKind.markNotificationRead => await repo.sendQueuedRead(entry),
        OutboxKind.markAllNotificationsRead => await repo.sendQueuedReadAll(
          entry,
        ),
        _ => throw StateError('no sender for ${entry.kind}'),
      },
      clock: () => clock,
    );
    repo = NotificationsRepository(
      cache: documents,
      remote: remote,
      outbox: () => outbox,
      signedInUserId: () => 'user-1',
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  test('a null is_read is unread, as the server means it', () async {
    remote.row('a', '2026-09-21T10:00:00Z', read: null);
    final items = await repo.refresh();
    expect(items.single.isRead, isFalse);
  });

  test('a read survives a refresh that lands before it is sent', () async {
    remote.row('a', '2026-09-21T10:00:00Z');
    await repo.refresh();

    remote.offline = true;
    await repo.markRead('a');
    await outbox.flush();
    remote.offline = false;

    // The server still says unread; the queued read wins on screen.
    final items = await repo.refresh();
    expect(items.single.isRead, isTrue);

    // Past the retry backoff the failed send earned.
    clock = clock.add(const Duration(minutes: 10));
    await outbox.flush();
    expect(remote.rows.single['is_read'], isTrue);
  });

  test('"mark all" stops at the newest one the customer saw', () async {
    remote
      ..row('a', '2026-09-21T09:00:00Z')
      ..row('b', '2026-09-21T10:00:00Z');
    await repo.refresh();

    await repo.markAllRead();
    // Written after the customer looked.
    remote.row('c', '2026-09-21T11:00:00Z');
    await outbox.flush();

    final items = await repo.refresh();
    expect(
      {for (final n in items) n.id: n.isRead},
      <String, bool>{'c': false, 'b': true, 'a': true},
    );
  });

  test('a read the server did not apply stays queued', () async {
    remote.row('a', '2026-09-21T10:00:00Z');
    await repo.refresh();
    remote.ignoresUpdates = true;

    await repo.markRead('a');
    final report = await outbox.flush();

    expect(report.sent, 0);
    expect(outbox.entries(includeDead: false), hasLength(1));
  });

  test('"mark all" the server did not apply stays queued', () async {
    remote.row('a', '2026-09-21T10:00:00Z');
    await repo.refresh();
    remote.ignoresUpdates = true;

    await repo.markAllRead();
    expect((await outbox.flush()).sent, 0);
  });

  test('a notification deleted meanwhile is done, not retried', () async {
    remote.row('a', '2026-09-21T10:00:00Z');
    await repo.refresh();
    remote.rows.clear();

    await repo.markRead('a');
    expect((await outbox.flush()).sent, 1);
  });

  group('whenLabel', () {
    final now = DateTime.utc(2026, 9, 21, 21, 30); // 00:30 on the 22nd, Cairo

    test('minutes and hours', () {
      expect(
        whenLabel(now.subtract(const Duration(seconds: 20)), now, 'UTC'),
        'دلوقتي',
      );
      expect(
        whenLabel(now.subtract(const Duration(minutes: 5)), now, 'UTC'),
        'من 5 دقيقة',
      );
      expect(
        whenLabel(now.subtract(const Duration(hours: 3)), now, 'UTC'),
        'من 3 ساعة',
      );
    });

    test('"yesterday" is the market\'s yesterday', () {
      // 20:00 UTC on the 21st: the same day in UTC, but yesterday in Cairo,
      // where it is already past midnight.
      final at = DateTime.utc(2026, 9, 21, 20);
      expect(whenLabel(at, now, 'UTC'), 'من 1 ساعة');
      expect(whenLabel(at, now, 'Africa/Cairo'), 'امبارح');
    });
  });
}
