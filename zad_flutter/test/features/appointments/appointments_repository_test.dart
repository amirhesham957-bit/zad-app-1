// مواعيدي offline first (ZAD_PLAN ٨ج.٢): one table for the page and the
// brain, queued writes laid over the server's rows, patches that never move a
// row the cron already moved.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/sync/outbox.dart';
import 'package:zad/core/data/sync/outbox_entry.dart';
import 'package:zad/features/appointments/data/appointments_repository.dart';

class _Remote implements AppointmentsRemote {
  final Map<String, Map<String, dynamic>> rows =
      <String, Map<String, dynamic>>{};
  bool offline = false;
  bool keepDeleted = false;

  void _net() {
    if (offline) throw const SocketException('offline');
  }

  @override
  Future<List<Map<String, dynamic>>> fetchFrom({
    required String userId,
    required DateTime since,
  }) async {
    _net();
    return <Map<String, dynamic>>[
      for (final r in rows.values)
        if (r['user_id'] == userId && r['status'] != 'cancelled')
          Map<String, dynamic>.of(r),
    ];
  }

  @override
  Future<Map<String, dynamic>?> insertReturning(
    Map<String, dynamic> row,
  ) async {
    _net();
    rows.putIfAbsent(row['id'] as String, () => Map<String, dynamic>.of(row));
    return Map<String, dynamic>.of(rows[row['id']]!);
  }

  @override
  Future<Map<String, dynamic>?> setStatusReturning(
    String id,
    String status,
  ) async {
    _net();
    final row = rows[id];
    if (row == null) return null;
    row['status'] = status;
    return Map<String, dynamic>.of(row);
  }

  @override
  Future<void> remove(String id) async {
    _net();
    if (!keepDeleted) rows.remove(id);
  }

  @override
  Future<bool> exists(String id) async => rows.containsKey(id);
}

Map<String, dynamic> _brainRow(String id, String title, String startsAt) =>
    <String, dynamic>{
      'id': id,
      'user_id': 'u',
      'title': title,
      'kind': 'medical',
      'starts_at': startsAt,
      'recurrence': 'once',
      'status': 'upcoming',
      'source': 'telegram',
    };

void main() {
  late Directory dir;
  late Box<String> cache;
  late Outbox outbox;
  late _Remote remote;
  late AppointmentsRepository repo;
  final now = DateTime.utc(2026, 10, 28, 9);
  var clock = now;
  var n = 0;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_appointments');
    Hive.init(dir.path);
    cache = await Hive.openBox<String>('docs');
    final outboxBox = await Hive.openBox<String>('outbox');
    remote = _Remote();
    clock = now;
    outbox = Outbox(
      box: outboxBox,
      clock: () => clock,
      send: (e) => switch (e.kind) {
        OutboxKind.addAppointment => repo.sendQueuedAdd(e),
        OutboxKind.setAppointmentStatus => repo.sendQueuedStatus(e),
        _ => repo.sendQueuedDelete(e),
      },
    );
    repo = AppointmentsRepository(
      cache: cache,
      remote: remote,
      outbox: () => outbox,
      newId: () => 'ap-${++n}',
      signedInUserId: () => 'u',
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  Future<String> addDentist() => repo.add(
    title: 'دكتور الأسنان',
    kind: 'medical',
    startsAt: DateTime.utc(2026, 10, 29, 14),
    remindMinutesBefore: 30,
    recurrence: 'once',
    placeLabel: ' ',
    forPerson: 'يوسف',
  );

  test('never loaded is not the same as empty', () async {
    expect(repo.view(), isNull);
    await repo.refresh(now: now);
    expect(repo.view(), isEmpty);
  });

  test('an add made offline is on the page at once and lands later', () async {
    remote.offline = true;
    final id = await addDentist();
    expect(repo.view()!.single.title, 'دكتور الأسنان');

    await outbox.flush();
    expect(remote.rows, isEmpty);
    expect(repo.view()!.single.id, id, reason: 'still shown while queued');

    remote.offline = false;
    clock = clock.add(const Duration(minutes: 10)); // past the backoff
    await outbox.flush();
    expect(remote.rows[id]!['source'], 'app');
    expect(remote.rows[id]!['for_person'], 'يوسف');
    expect(remote.rows[id]!['place_label'], isNull);
    expect(outbox.entries(), isEmpty);
    expect(repo.view()!.single.id, id);
  });

  test(
    "the brain's rows from Telegram, chat and voice show on the page",
    () async {
      remote.rows['t1'] = _brainRow('t1', 'تحليل دم', '2026-10-30T06:00:00Z');
      remote.rows['v1'] = <String, dynamic>{
        ..._brainRow('v1', 'اجتماع', '2026-10-28T12:00:00Z'),
        'source': 'voice',
      };
      final ids = (await repo.refresh(now: now)).map((a) => a.id).toList();
      expect(ids, <String>['v1', 't1']);
    },
  );

  test('a row the brain deleted leaves the page on the next refresh', () async {
    remote.rows['t1'] = _brainRow('t1', 'تحليل دم', '2026-10-30T06:00:00Z');
    await repo.refresh(now: now);
    remote.rows.remove('t1');
    expect(await repo.refresh(now: now), isEmpty);
  });

  test('a cancel waits for the net, and only the status is sent', () async {
    remote.rows['t1'] = _brainRow('t1', 'تحليل دم', '2026-10-30T06:00:00Z');
    await repo.refresh(now: now);
    remote.offline = true;
    await repo.setStatus('t1', 'cancelled');
    expect(repo.view(), isEmpty, reason: 'cancelled rows are not listed');

    // Meanwhile the brain moved it, then the phone came back online.
    remote
      ..offline = false
      ..rows['t1']!['starts_at'] = '2026-10-31T06:00:00Z';
    expect(
      await repo.refresh(now: now),
      isEmpty,
      reason: 'a refresh keeps the queued cancel on top',
    );
    await outbox.flush();
    expect(remote.rows['t1']!['status'], 'cancelled');
    expect(
      remote.rows['t1']!['starts_at'],
      '2026-10-31T06:00:00Z',
      reason: "a patch, not the phone's stale copy of the row",
    );
  });

  test('a replayed add does not move a row the cron already moved', () async {
    final id = await addDentist();
    remote.rows[id] = <String, dynamic>{
      ...outbox.entries().single.payload,
      'starts_at': '2026-11-05T14:00:00Z',
    };
    await outbox.flush();
    expect(remote.rows[id]!['starts_at'], '2026-11-05T14:00:00Z');
    expect(repo.view()!.single.startsAtRaw, '2026-11-05T14:00:00Z');
  });

  test('a delete of a queued add sends nothing but the delete', () async {
    remote.offline = true;
    final id = await addDentist();
    await repo.remove(id);
    expect(repo.view(), isEmpty);
    expect(outbox.entries().map((e) => e.kind), <String>[
      OutboxKind.deleteAppointment,
    ]);
  });

  test('a delete is retried while the row is still there', () async {
    remote.rows['t1'] = _brainRow('t1', 'تحليل دم', '2026-10-30T06:00:00Z');
    await repo.refresh(now: now);
    remote.keepDeleted = true;
    await repo.remove('t1');
    await outbox.flush();
    expect(outbox.entries(), isNotEmpty);
    expect(await repo.refresh(now: now), isEmpty);
  });

  test('a status for a row deleted elsewhere is simply done', () async {
    remote.rows['t1'] = _brainRow('t1', 'تحليل دم', '2026-10-30T06:00:00Z');
    await repo.refresh(now: now);
    remote.rows.remove('t1');
    await repo.setStatus('t1', 'done');
    await outbox.flush();
    expect(outbox.entries(), isEmpty);
    expect(repo.view(), isEmpty);
  });

  test('another account on the device sees none of it', () async {
    remote.offline = true;
    await addDentist();
    final other = AppointmentsRepository(
      cache: cache,
      remote: remote,
      outbox: () => outbox,
      newId: () => 'x',
      signedInUserId: () => 'someone-else',
    );
    expect(other.view(), isNull);
  });
}
