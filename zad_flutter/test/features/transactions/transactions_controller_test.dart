// The list's contract: the rows are there in the first read, the period comes
// from the budget so two screens cannot disagree, and a failed refresh never
// replaces a readable list with an error.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/data/providers.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/budget/data/budget_repository.dart';
import 'package:zad/features/budget/domain/budget_snapshot.dart';
import 'package:zad/features/transactions/application/transactions_controller.dart';
import 'package:zad/features/transactions/data/transactions_remote.dart';
import 'package:zad/features/transactions/data/transactions_repository.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

class _FakeBudgetRemote implements BudgetRemote {
  @override
  Future<Map<String, dynamic>> fetch({
    required String userId,
    required String timeZone,
  }) async => _budgetState();
}

class _FakeTxnRemote implements TransactionsRemote {
  @override
  Future<Map<String, dynamic>?> updateReturning(
    Map<String, dynamic> patch,
  ) async => null;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<bool> exists(String id) async => false;

  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  Exception? failWith;
  int fetches = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchPeriod({
    required String userId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    fetches++;
    if (failWith case final e?) throw e;
    return rows;
  }

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async => row;
}

Map<String, dynamic> _budgetState() => <String, dynamic>{
  'user_id': 'user-1',
  'currency': 'ج.م',
  'timezone': 'Africa/Cairo',
  'spent': 0,
  'income': 0,
  'committed': 0,
  'days_left': 5,
  'cycle_length_days': 31,
  'threat': 'SAFE',
  'unverified_count': 0,
  'computed_at': '2026-09-20T12:00:00Z',
  'available': 1000,
  'remaining': 1000,
  'opening_balance': 8000,
  'limit_confirmed': true,
  'cycle_start': '2026-08-25',
  'cycle_end': '2026-09-25',
};

Map<String, dynamic> _row(String id, {String at = '2026-09-19T10:00:00Z'}) =>
    <String, dynamic>{
      'id': id,
      'user_id': 'user-1',
      'amount': 50.0,
      'title': 'قهوة',
      'category': 'مأكولات',
      'is_expense': true,
      'created_at': at,
      'wallet': 'cash',
      'txn_kind': 'expense',
      'counts_toward_budget': true,
    };

void main() {
  late Directory dir;
  late Box<String> documents;
  late Box<String> transactions;
  late Box<String> outboxBox;
  late _FakeTxnRemote remote;
  late ProviderContainer container;

  var now = DateTime.parse('2026-09-20T12:00:00Z');

  setUpAll(tz_data.initializeTimeZones);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_txn_screen_test');
    Hive.init(dir.path);
    documents = await Hive.openBox<String>('documents');
    transactions = await Hive.openBox<String>('transactions');
    outboxBox = await Hive.openBox<String>('outbox');
    remote = _FakeTxnRemote();
    now = DateTime.parse('2026-09-20T12:00:00Z');

    // A budget snapshot has to be cached, or there is no period and the list
    // has nothing to be a list of.
    await documents.put(
      'budget_state',
      jsonEncode(BudgetSnapshot.fromJson(_budgetState()).toJson()),
    );

    late TransactionsRepository txns;
    final outbox = Outbox(
      box: outboxBox,
      send: (e) => txns.sendQueued(e),
      clock: () => now,
    );
    txns = TransactionsRepository(
      cache: transactions,
      remote: remote,
      outbox: () => outbox,
      newId: () => 'txn-${transactions.length + 1}',
      signedInUserId: () => 'user-1',
    );

    container = ProviderContainer(
      overrides: [
        nowProvider.overrideWithValue(() => now),
        transactionsRepositoryProvider.overrideWithValue(txns),
        budgetRepositoryProvider.overrideWithValue(
          BudgetRepository(
            cache: documents,
            remote: _FakeBudgetRemote(),
            signedInUserId: () => 'user-1',
          ),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  Future<void> seedCache(List<String> ids) async {
    for (final id in ids) {
      await transactions.put(
        id,
        jsonEncode(ZadTransaction.fromJson(_row(id)).toCacheJson()),
      );
    }
  }

  group('instant open', () {
    test('the cached rows are in the first read, with no await', () async {
      await seedCache(<String>['a', 'b']);

      final view = container.read(transactionsControllerProvider);

      expect(view.rows, hasLength(2));
      expect(remote.fetches, 0, reason: 'the first read waited on the network');
    });

    test('an empty cache is an empty list, not a spinner', () async {
      final view = container.read(transactionsControllerProvider);
      expect(view.isEmpty, isTrue);
    });
  });

  group('the period', () {
    test('comes from the budget, so the two screens cannot disagree', () {
      // The card on home and this list report the same days because they take
      // the same range from the same snapshot.
      final view = container.read(transactionsControllerProvider);
      final budget = container.read(budgetControllerProvider);

      expect(view.period, isNotNull);
      expect(view.period!.periodStart, budget.snapshot!.cycleStart);
      expect(view.period!.periodEnd, budget.snapshot!.cycleEnd);
    });

    test('with no snapshot there is no period and no list', () async {
      await documents.delete('budget_state');
      final fresh = ProviderContainer(
        overrides: [
          nowProvider.overrideWithValue(() => now),
          transactionsRepositoryProvider.overrideWithValue(
            container.read(transactionsRepositoryProvider),
          ),
          budgetRepositoryProvider.overrideWithValue(
            BudgetRepository(
              cache: documents,
              remote: _FakeBudgetRemote(),
              signedInUserId: () => 'user-1',
            ),
          ),
        ],
      );
      addTearDown(fresh.dispose);

      final view = fresh.read(transactionsControllerProvider);
      expect(view.period, isNull);
      expect(view.isEmpty, isTrue);
    });
  });

  group('refresh', () {
    test('replaces the rows and clears the mark', () async {
      await seedCache(<String>['a']);
      container.read(transactionsControllerProvider);

      remote.rows = <Map<String, dynamic>>[_row('a'), _row('b')];
      await container
          .read(transactionsControllerProvider.notifier)
          .refresh(force: true);

      final view = container.read(transactionsControllerProvider);
      expect(view.rows, hasLength(2));
      expect(view.isStale, isFalse);
    });

    test('a failure keeps the rows and marks them', () async {
      await seedCache(<String>['a']);
      container.read(transactionsControllerProvider);

      remote.failWith = const SocketException('offline');
      await container
          .read(transactionsControllerProvider.notifier)
          .refresh(force: true);

      final view = container.read(transactionsControllerProvider);
      expect(
        view.rows,
        hasLength(1),
        reason: 'a readable list was thrown away',
      );
      expect(view.isStale, isTrue);
      expect(view.error, isNotNull);
    });
  });

  group('the cooldown', () {
    test('a re-entry inside the window fetches nothing', () async {
      await container
          .read(transactionsControllerProvider.notifier)
          .refresh(force: true);
      final after = remote.fetches;

      now = now.add(const Duration(minutes: 1));
      await container.read(transactionsControllerProvider.notifier).refresh();

      expect(remote.fetches, after, reason: 'the cooldown was ignored');
    });

    test('a pull-to-refresh always fetches', () async {
      await container
          .read(transactionsControllerProvider.notifier)
          .refresh(force: true);
      final after = remote.fetches;

      await container
          .read(transactionsControllerProvider.notifier)
          .refresh(force: true);

      expect(remote.fetches, greaterThan(after));
    });
  });

  group('a local write', () {
    test('shows without a round trip, and is marked', () async {
      container.read(transactionsControllerProvider);

      await container
          .read(transactionsRepositoryProvider)
          .record(
            (id) => ZadTransaction.expense(
              id: id,
              userId: 'user-1',
              amount: 80,
              title: 'عشا',
              createdAt: DateTime.parse('2026-09-19T20:00:00Z'),
              wallet: Wallet.cash,
            ),
          );
      container.read(transactionsControllerProvider.notifier).reloadFromCache();

      final view = container.read(transactionsControllerProvider);
      expect(view.rows, hasLength(1));
      expect(view.pendingCount, 1);
    });
  });
}
