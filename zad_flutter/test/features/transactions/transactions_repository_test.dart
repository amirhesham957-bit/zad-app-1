// The offline-first cycle end to end: a write lands locally with no network,
// the outbox carries it up later, and the server's version of the row replaces
// the optimistic one.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/core/period/budget_period.dart';
import 'package:zad/core/period/payday.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/features/transactions/data/transactions_remote.dart';
import 'package:zad/features/transactions/data/transactions_repository.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

/// Stands in for the server, including the parts of it that rewrite a row.
class _FakeRemote implements TransactionsRemote {
  final Map<String, Map<String, dynamic>> rows =
      <String, Map<String, dynamic>>{};
  int upserts = 0;
  Exception? failWith;

  /// Applied to a row on its way in, to imitate a BEFORE INSERT trigger.
  Map<String, dynamic> Function(Map<String, dynamic>)? onInsert;

  @override
  Future<List<Map<String, dynamic>>> fetchPeriod({
    required String userId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    if (failWith case final error?) throw error;
    return rows.values.where((r) {
      final at = DateTime.parse(r['created_at'] as String).toUtc();
      return !at.isBefore(startsAt) && at.isBefore(endsAt);
    }).toList();
  }

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async {
    if (failWith case final error?) throw error;
    upserts++;
    final id = row['id'] as String;
    // ignoreDuplicates: an id already present is left exactly as it is.
    rows[id] ??= onInsert?.call(row) ?? Map<String, dynamic>.from(row);
    return rows[id];
  }
}

void main() {
  late Directory dir;
  late Box<String> cache;
  late Box<String> outboxBox;
  late _FakeRemote remote;
  late Outbox outbox;
  late TransactionsRepository repo;
  late BudgetPeriod september;

  var now = DateTime.utc(2026, 9, 19, 12);
  var nextId = 0;

  setUpAll(tz_data.initializeTimeZones);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_repo_test');
    Hive.init(dir.path);
    cache = await Hive.openBox<String>('cache');
    outboxBox = await Hive.openBox<String>('outbox');
    remote = _FakeRemote();
    now = DateTime.utc(2026, 9, 19, 12);
    nextId = 0;

    outbox = Outbox(
      box: outboxBox,
      send: (entry) => repo.sendQueued(entry),
      clock: () => now,
    );
    repo = TransactionsRepository(
      cache: cache,
      remote: remote,
      outbox: () => outbox,
      newId: () => 'txn-${++nextId}',
      signedInUserId: () => 'user-1',
    );

    september = BudgetPeriod.at(
      at: now,
      country: 'EG',
      cycleStartDay: null,
      anchor: CycleAnchor.dayOfMonth,
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  ZadTransaction coffee(String id) => ZadTransaction.expense(
    id: id,
    userId: 'user-1',
    amount: 50,
    title: 'قهوة',
    createdAt: now,
    wallet: Wallet.cash,
    category: 'مأكولات',
  );

  group('writing', () {
    test('a write lands locally without touching the network', () async {
      final txn = await repo.record(coffee);

      expect(txn.isPending, isTrue);
      expect(remote.upserts, 0, reason: 'record() must not call the server');
      expect(repo.cachedPeriod(september).single.id, txn.id);
      expect(outbox.entries().single.id, txn.id);
    });

    test(
      'the cached row, the queued entry and the server row share one id',
      () async {
        final txn = await repo.record(coffee);
        await outbox.flush();

        expect(cache.containsKey(txn.id), isTrue);
        expect(remote.rows.keys, <String>[txn.id]);
      },
    );

    test('flushing confirms the row and clears pending', () async {
      await repo.record(coffee);
      final report = await outbox.flush();

      expect(report.sent, 1);
      final stored = repo.cachedPeriod(september).single;
      expect(stored.isPending, isFalse);
      expect(stored.amount, 50);
    });

    test("the server's amount replaces the optimistic one", () async {
      // What a foreign-currency row comes back as once the server has converted
      // it. The client could not have computed this: the rates live on
      // the server.
      remote.onInsert = (row) => <String, dynamic>{
        ...row,
        'amount': 1550.25,
        'currency': 'EGP',
      };

      await repo.record(coffee);
      await outbox.flush();

      expect(repo.cachedPeriod(september).single.amount, 1550.25);
      expect(repo.cachedPeriod(september).single.currency, 'EGP');
    });

    test('replaying a sent write does not insert a second row', () async {
      final txn = await repo.record(coffee);
      await outbox.flush();

      // The shape of an ambiguous failure: the write landed but the reply
      // was lost, so the entry is still queued and gets sent again.
      await outbox.enqueue(
        id: txn.id,
        kind: 'insert_transaction',
        payload: txn.toInsertJson(),
      );
      await outbox.flush();

      expect(remote.rows, hasLength(1));
      expect(repo.cachedPeriod(september), hasLength(1));
    });

    test('an offline write is still there after the app is killed', () async {
      remote.failWith = const SocketException('offline');
      await repo.record(coffee);
      await outbox.flush();

      expect(outbox.entries(includeDead: false), hasLength(1));
      expect(repo.cachedPeriod(september).single.isPending, isTrue);

      remote.failWith = null;
      now = now.add(const Duration(minutes: 10));
      final report = await outbox.flush();

      expect(report.sent, 1);
      expect(repo.cachedPeriod(september).single.isPending, isFalse);
    });
  });

  group('reading', () {
    test(
      'the cached read is synchronous — this is what instant-open means',
      () {
        // No await: the first frame can call this.
        expect(repo.cachedPeriod(september), isEmpty);
      },
    );

    test('rows outside the period are not returned', () async {
      await repo.record(coffee);

      final august = BudgetPeriod.at(
        at: DateTime.utc(2026, 8, 15, 12),
        country: 'EG',
        cycleStartDay: null,
        anchor: CycleAnchor.dayOfMonth,
      );

      expect(repo.cachedPeriod(september), hasLength(1));
      expect(repo.cachedPeriod(august), isEmpty);
    });

    test(
      'a refresh replaces the period and drops rows the server no longer has',
      () async {
        await repo.record(coffee);
        await outbox.flush();
        expect(repo.cachedPeriod(september), hasLength(1));

        // Deleted elsewhere — on another device, or in the Telegram bot.
        remote.rows.clear();
        final after = await repo.refreshPeriod(september);

        expect(after, isEmpty);
      },
    );

    test('a refresh keeps pending rows the server has not seen yet', () async {
      remote.failWith = const SocketException('offline');
      await repo.record(coffee);
      await outbox.flush();
      remote.failWith = null;

      // The refresh succeeds while the write is still queued. The user's row
      // must not blink out of the list and back in when the outbox drains.
      final after = await repo.refreshPeriod(september);

      expect(after, hasLength(1));
      expect(after.single.isPending, isTrue);
    });

    test('newest first', () async {
      await repo.record(coffee);
      now = now.add(const Duration(hours: 1));
      await repo.record(coffee);

      final rows = repo.cachedPeriod(september);
      expect(rows.first.createdAt.isAfter(rows.last.createdAt), isTrue);
    });
  });
}
