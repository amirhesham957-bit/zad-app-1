// The home screen's contract: draw what is on the device in the first frame,
// ask the server afterwards, and never let the asking hide the figures.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/features/budget/application/budget_controller.dart';
import 'package:zad/features/budget/data/budget_repository.dart';
import 'package:zad/features/budget/domain/budget_snapshot.dart';
import 'package:zad/features/transactions/data/transactions_remote.dart';
import 'package:zad/features/transactions/data/transactions_repository.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

/// Stands in for `zad_budget_state()`.
class _FakeBudgetRemote implements BudgetRemote {
  int calls = 0;
  Exception? failWith;
  Map<String, dynamic> answer = _state();

  /// The `p_tz` the last call sent.
  String? sentTimeZone;

  @override
  Future<Map<String, dynamic>> fetch({
    required String userId,
    required String timeZone,
  }) async {
    calls++;
    sentTimeZone = timeZone;
    if (failWith case final error?) throw error;
    return answer;
  }
}

class _FakeTransactionsRemote implements TransactionsRemote {
  @override
  Future<Map<String, dynamic>?> updateReturning(
    Map<String, dynamic> patch,
  ) async => null;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<bool> exists(String id) async => false;

  @override
  Future<List<Map<String, dynamic>>> fetchPeriod({
    required String userId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async => <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async => row;
}

/// The shape `zad_budget_state()` actually returns, with the keys this app
/// reads. `available` is `remaining - committed`, and both are null when no
/// limit has been confirmed.
Map<String, dynamic> _state({
  String userId = 'user-1',
  double? remaining = 4820.5,
  double? available = 3620.5,
  double spent = 3179.5,
  double committed = 1200,
  String cycleStart = '2026-08-25',
  String cycleEnd = '2026-09-25',
}) => <String, dynamic>{
  'user_id': userId,
  'currency': 'ج.م',
  'timezone': 'Africa/Cairo',
  'spent': spent,
  'income': 0,
  'committed': committed,
  'days_left': 5,
  'cycle_length_days': 31,
  'threat': 'SAFE',
  'unverified_count': 0,
  'computed_at': '2026-09-19T12:00:00Z',
  'available': available,
  'remaining': remaining,
  'opening_balance': 8000,
  'limit_confirmed': remaining != null,
  'cycle_start': cycleStart,
  'cycle_end': cycleEnd,
};

void main() {
  late Directory dir;
  late Box<String> documents;
  late Box<String> transactions;
  late Box<String> outboxBox;
  late _FakeBudgetRemote remote;
  late ProviderContainer container;

  var now = DateTime.parse('2026-09-19T12:00:00Z');
  var signedIn = 'user-1';
  var zoneArgument = '';

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_budget_test');
    Hive.init(dir.path);
    documents = await Hive.openBox<String>('documents');
    transactions = await Hive.openBox<String>('transactions');
    outboxBox = await Hive.openBox<String>('outbox');
    remote = _FakeBudgetRemote();
    now = DateTime.parse('2026-09-19T12:00:00Z');
    signedIn = 'user-1';
    zoneArgument = '';

    late TransactionsRepository txns;
    final outbox = Outbox(
      box: outboxBox,
      send: (entry) => txns.sendQueued(entry),
      clock: () => now,
    );
    txns = TransactionsRepository(
      cache: transactions,
      remote: _FakeTransactionsRemote(),
      outbox: () => outbox,
      newId: () => 'txn-${transactions.length + 1}',
      signedInUserId: () => signedIn,
    );

    container = ProviderContainer(
      overrides: [
        nowProvider.overrideWithValue(() => now),
        serverTimeZoneArgumentProvider.overrideWithValue(() => zoneArgument),
        transactionsRepositoryProvider.overrideWithValue(txns),
        budgetRepositoryProvider.overrideWithValue(
          BudgetRepository(
            cache: documents,
            remote: remote,
            signedInUserId: () => signedIn,
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

  /// Writes a snapshot straight into the box, as a previous session would have.
  Future<void> seedCache(Map<String, dynamic> state) => documents.put(
    'budget_state',
    jsonEncode(BudgetSnapshot.fromJson(state).toJson()),
  );

  group('instant open', () {
    test('the first read is already the cached figures, with no await', () {
      // This is the whole claim of the screen: the first frame has a number in
      // it. If this ever needs an await, the screen has a spinner again.
      unawaited(
        documents.put(
          'budget_state',
          jsonEncode(BudgetSnapshot.fromJson(_state()).toJson()),
        ),
      );

      final view = container.read(budgetControllerProvider);

      expect(view.snapshot, isNotNull);
      expect(view.spendable, 3620.5);
      expect(remote.calls, 0, reason: 'the first read waited on the network');
    });

    test('an empty cache is empty, not a guess', () {
      final view = container.read(budgetControllerProvider);
      expect(view.snapshot, isNull);
      expect(view.spendable, isNull);
    });

    test("another account's cached figures are never shown", () async {
      await seedCache(_state(userId: 'someone-else'));

      final view = container.read(budgetControllerProvider);

      expect(
        view.snapshot,
        isNull,
        reason: "the previous user's budget survived a sign-in",
      );
    });
  });

  group('refresh', () {
    test('runs after the first read and replaces the figures', () async {
      await seedCache(_state(available: 100));
      expect(container.read(budgetControllerProvider).spendable, 100);

      remote.answer = _state(available: 999);
      await container
          .read(budgetControllerProvider.notifier)
          .refresh(force: true);

      expect(container.read(budgetControllerProvider).spendable, 999);
      expect(container.read(budgetControllerProvider).isStale, isFalse);
    });

    test('caches what it fetched, so the next launch is instant too', () async {
      await container
          .read(budgetControllerProvider.notifier)
          .refresh(force: true);
      expect(documents.get('budget_state'), isNotNull);
    });

    test(
      "sends the account's zone argument, never the last snapshot's zone",
      () async {
        // The server resolves `coalesce(nullif(p_tz, ''), market zone)`: the
        // argument outranks the account's country. Echoing the snapshot's
        // zone back made the first answer — UTC, for an account with no
        // country yet — permanent, whatever country was set afterwards.
        await seedCache(_state());
        expect(
          container.read(budgetControllerProvider).snapshot?.timeZone,
          'Africa/Cairo',
        );

        await container
            .read(budgetControllerProvider.notifier)
            .refresh(force: true);
        expect(
          remote.sentTimeZone,
          '',
          reason: 'with no known country the server must decide the zone',
        );

        zoneArgument = 'Asia/Riyadh';
        await container
            .read(budgetControllerProvider.notifier)
            .refresh(force: true);
        expect(remote.sentTimeZone, 'Asia/Riyadh');
      },
    );

    test('a failure keeps the figures and marks them unconfirmed', () async {
      await seedCache(_state(available: 100));
      container.read(budgetControllerProvider);

      remote.failWith = const SocketException('offline');
      await container
          .read(budgetControllerProvider.notifier)
          .refresh(force: true);

      final view = container.read(budgetControllerProvider);
      // The number stays. Replacing a readable figure with an error screen
      // because a refresh failed is the opposite of offline-first.
      expect(view.spendable, 100);
      expect(view.isStale, isTrue);
      expect(view.error, isNotNull);
    });
  });

  group('the cooldown', () {
    test('a re-entry inside the window fetches nothing', () async {
      await container
          .read(budgetControllerProvider.notifier)
          .refresh(force: true);
      expect(remote.calls, 1);

      now = now.add(const Duration(minutes: 1));
      await container.read(budgetControllerProvider.notifier).refresh();

      expect(remote.calls, 1, reason: 'the cooldown was ignored');
    });

    test('after the window it fetches again', () async {
      await container
          .read(budgetControllerProvider.notifier)
          .refresh(force: true);
      now = now.add(BudgetController.cooldown + const Duration(seconds: 1));
      await container.read(budgetControllerProvider.notifier).refresh();

      expect(remote.calls, 2);
    });

    test('a pull-to-refresh always fetches', () async {
      await container
          .read(budgetControllerProvider.notifier)
          .refresh(force: true);
      await container
          .read(budgetControllerProvider.notifier)
          .refresh(force: true);

      expect(remote.calls, 2);
    });
  });

  group('queued spending', () {
    test('an unsent expense moves the figure straight away', () async {
      await seedCache(_state());
      final txns = container.read(transactionsRepositoryProvider);

      await txns.record(
        (id) => ZadTransaction.expense(
          id: id,
          userId: 'user-1',
          amount: 120,
          title: 'قهوة',
          createdAt: DateTime.parse('2026-09-19T10:00:00Z'),
          wallet: Wallet.cash,
        ),
      );

      container.read(budgetControllerProvider.notifier).recomputePending();
      final view = container.read(budgetControllerProvider);

      // Telling the user their balance has not moved because a request is
      // queued would be describing the network, not their money.
      expect(view.pendingSpend, 120);
      expect(view.spendable, 3500.5);
    });

    test(
      'a row queued from a closed cycle is left out of these figures',
      () async {
        await seedCache(_state());
        final txns = container.read(transactionsRepositoryProvider);

        await txns.record(
          (id) => ZadTransaction.expense(
            id: id,
            userId: 'user-1',
            amount: 500,
            title: 'قديم',
            // Before cycle_start (25 Aug).
            createdAt: DateTime.parse('2026-08-01T10:00:00Z'),
            wallet: Wallet.cash,
          ),
        );

        container.read(budgetControllerProvider.notifier).recomputePending();
        expect(container.read(budgetControllerProvider).pendingSpend, 0);
      },
    );
  });

  group('a cycle that has already ended', () {
    test('cached figures from a closed cycle are marked unconfirmed', () async {
      // Payday came, the server reset, and this device has not synced since.
      await seedCache(_state(cycleStart: '2026-07-25', cycleEnd: '2026-08-25'));

      final view = container.read(budgetControllerProvider);

      expect(view.snapshot, isNotNull, reason: 'the figures were thrown away');
      expect(view.isStale, isTrue);
    });

    test('a current cycle is not marked', () async {
      await seedCache(_state());
      expect(container.read(budgetControllerProvider).isStale, isFalse);
    });
  });
}
