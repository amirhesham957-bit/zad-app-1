// Obligations: Kotlin's due-date and status rules, and the repository's
// offline-first contract with its read-back.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/obligations/data/obligations_repository.dart';
import 'package:zad/features/obligations/domain/obligation.dart';

class _Remote implements ObligationsRemote {
  final Map<String, Map<String, dynamic>> rows =
      <String, Map<String, dynamic>>{};

  /// Imitates a write the table did not keep.
  bool dropAmount = false;
  bool keepDeleted = false;

  @override
  Future<List<Map<String, dynamic>>> fetchActive({
    required String userId,
  }) async => rows.values.where((r) => r['active'] == true).toList();

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async {
    final stored = Map<String, dynamic>.from(row);
    if (dropAmount) stored['amount'] = rows[row['id']]?['amount'] ?? 1;
    rows[row['id'] as String] = stored;
    return stored;
  }

  @override
  Future<void> remove(String id) async {
    if (!keepDeleted) rows.remove(id);
  }

  @override
  Future<bool> exists(String id) async => rows.containsKey(id);
}

Obligation _o({int? dueDay, Recurrence? recurrence, DateTime? dueDate}) =>
    Obligation(
      id: 'o',
      userId: 'u',
      title: 'إيجار',
      amount: 3000,
      dueDay: dueDay,
      dueDate: dueDate,
      recurrence: recurrence ?? Recurrence.monthly,
    );

void main() {
  group('next due date', () {
    final today = DateTime.utc(2026, 9, 25);

    test('this month when the day is still ahead', () {
      expect(nextDueDate(_o(dueDay: 28), today), DateTime.utc(2026, 9, 28));
    });

    test('today counts as due today', () {
      expect(nextDueDate(_o(dueDay: 25), today), DateTime.utc(2026, 9, 25));
    });

    test('next month when it has passed', () {
      expect(nextDueDate(_o(dueDay: 5), today), DateTime.utc(2026, 10, 5));
    });

    test("the 31st lands on a short month's last day", () {
      expect(nextDueDate(_o(dueDay: 31), today), DateTime.utc(2026, 9, 30));
    });

    test('quarterly steps three months, over the year end', () {
      final q = _o(dueDay: 5, recurrence: Recurrence.quarterly);
      expect(
        nextDueDate(q, DateTime.utc(2026, 11, 20)),
        DateTime.utc(2027, 2, 5),
      );
    });

    test('a one-off gone by has no next date', () {
      final once = _o(
        recurrence: Recurrence.once,
        dueDate: DateTime.utc(2026, 9, 2),
      );
      expect(nextDueDate(once, today), isNull);
      expect(obligationStanding(once, today).status, ObligationStatus.paid);
    });

    test('within a week is pending, further out is scheduled', () {
      expect(
        obligationStanding(_o(dueDay: 28), today).status,
        ObligationStatus.pending,
      );
      expect(
        obligationStanding(_o(dueDay: 15), today).status,
        ObligationStatus.scheduled,
      );
    });
  });

  group('the repository', () {
    late Directory dir;
    late Box<String> cache;
    late Outbox outbox;
    late _Remote remote;
    late ObligationsRepository repo;
    var n = 0;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('zad_obligations');
      Hive.init(dir.path);
      cache = await Hive.openBox<String>('docs');
      final outboxBox = await Hive.openBox<String>('outbox');
      remote = _Remote();
      outbox = Outbox(
        box: outboxBox,
        send: (e) => e.kind == OutboxKind.deleteObligation
            ? repo.sendQueuedDelete(e)
            : repo.sendQueued(e),
      );
      repo = ObligationsRepository(
        cache: cache,
        remote: remote,
        outbox: () => outbox,
        newId: () => 'ob-${++n}',
        signedInUserId: () => 'u',
      );
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });

    test('an add is on the device at once, confirmed, and sent', () async {
      await repo.add(
        title: 'إيجار',
        amount: 3000,
        kind: ObligationKind.rent,
        recurrence: Recurrence.monthly,
        dueDay: 1,
      );
      expect(repo.cached().single.isPending, isTrue);

      await outbox.flush();
      expect(remote.rows.values.single['confirmed'], isTrue);
      expect(repo.cached().single.isPending, isFalse);
      expect(outbox.entries(), isEmpty);
    });

    test('a write that does not read back is kept for a retry', () async {
      remote.dropAmount = true;
      await repo.add(
        title: 'قسط',
        amount: 900,
        kind: ObligationKind.installment,
        recurrence: Recurrence.monthly,
      );
      await outbox.flush();
      expect(outbox.entries(), isNotEmpty);
    });

    test(
      'a delete goes, and is retried while the row is still there',
      () async {
        final o = await repo.add(
          title: 'قسط',
          amount: 900,
          kind: ObligationKind.installment,
          recurrence: Recurrence.monthly,
        );
        await outbox.flush();
        remote.keepDeleted = true;

        await repo.remove(o.id);
        expect(repo.cached(), isEmpty);
        await outbox.flush();
        // Backed off and waiting, not believed gone.
        expect(outbox.entries(), isNotEmpty);
      },
    );

    test(
      'a refresh does not bring back a row whose delete is queued',
      () async {
        final o = await repo.add(
          title: 'قسط',
          amount: 900,
          kind: ObligationKind.installment,
          recurrence: Recurrence.monthly,
        );
        await outbox.flush();
        remote.keepDeleted = true;
        await repo.remove(o.id);

        await repo.refresh();
        expect(repo.cached(), isEmpty);
      },
    );
  });
}
