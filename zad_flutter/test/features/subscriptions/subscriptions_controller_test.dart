// The screen's side: marking a charge paid books the money and stops the
// budget reserving it, the day is the market's, and the budget is asked again
// only once the change has landed.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/data/local/boxes.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';
import 'package:zad/features/budget/data/budget_repository.dart';
import 'package:zad/features/settings/data/settings_repository.dart';
import 'package:zad/features/settings/domain/account_settings.dart';
import 'package:zad/features/subscriptions/application/subscriptions_controller.dart';
import 'package:zad/features/subscriptions/data/subscriptions_remote.dart';
import 'package:zad/features/subscriptions/data/subscriptions_repository.dart';
import 'package:zad/features/subscriptions/domain/renewal.dart';
import 'package:zad/features/transactions/data/transactions_remote.dart';
import 'package:zad/features/transactions/data/transactions_repository.dart';
import 'package:zad/features/transactions/domain/transaction.dart';

class _Subs implements SubscriptionsRemote {
  final Map<String, Map<String, dynamic>> rows =
      <String, Map<String, dynamic>>{};
  bool offline = false;

  @override
  Future<List<Map<String, dynamic>>> fetchAll({required String userId}) async {
    if (offline) throw const SocketException('offline');
    return rows.values.toList();
  }

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async {
    if (offline) throw const SocketException('offline');
    rows[row['id'] as String] = <String, dynamic>{...row};
    return <String, dynamic>{...row};
  }

  @override
  Future<void> remove(String id) async {
    if (offline) throw const SocketException('offline');
    rows.remove(id);
  }
}

class _Txns implements TransactionsRemote {
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

class _NoSettings implements SettingsRemote {
  @override
  Future<Map<String, dynamic>?> fetch({required String userId}) =>
      Future<Map<String, dynamic>?>.error(const SocketException('offline'));

  @override
  Future<Map<String, dynamic>?> upsertReturning(Map<String, dynamic> row) =>
      Future<Map<String, dynamic>?>.error(const SocketException('offline'));
}

class _Budget implements BudgetRemote {
  int calls = 0;

  @override
  Future<Map<String, dynamic>> fetch({
    required String userId,
    required String timeZone,
  }) async {
    calls++;
    throw const SocketException('not under test');
  }
}

void main() {
  late Directory dir;
  late Box<String> documents;
  late Box<String> transactions;
  late Box<String> subsBox;
  late Box<String> outboxBox;
  late _Subs subs;
  late _Budget budget;
  late Outbox outbox;
  late ProviderContainer container;

  // 22:30 UTC is already the 22nd in Cairo (UTC+3 in September).
  var now = DateTime.utc(2026, 9, 21, 22, 30);
  var run = 0;

  setUpAll(tz_data.initializeTimeZones);

  setUp(() async {
    run++;
    now = DateTime.utc(2026, 9, 21, 22, 30);
    dir = await Directory.systemTemp.createTemp('zad_subs_ctrl_test');
    Hive.init(dir.path);
    documents = await Hive.openBox<String>('documents$run');
    transactions = await Hive.openBox<String>('transactions$run');
    subsBox = await Hive.openBox<String>('subs$run');
    outboxBox = await Hive.openBox<String>('outbox$run');
    subs = _Subs();
    budget = _Budget();

    await documents.put(
      'account_settings',
      jsonEncode(const AccountSettings(country: 'EG').toJson()),
    );

    late SubscriptionsRepository subsRepo;
    late TransactionsRepository txns;
    outbox = Outbox(
      box: outboxBox,
      send: (entry) async => switch (entry.kind) {
        OutboxKind.upsertSubscription => await subsRepo.sendQueued(entry),
        OutboxKind.deleteSubscription => await subsRepo.sendQueuedDelete(entry),
        OutboxKind.insertTransaction => await txns.sendQueued(entry),
        _ => throw StateError('no sender for ${entry.kind}'),
      },
      clock: () => now,
    );
    var ids = 0;
    subsRepo = SubscriptionsRepository(
      cache: subsBox,
      remote: subs,
      outbox: () => outbox,
      newId: () => 's${ids++}',
      signedInUserId: () => 'user-1',
    );
    txns = TransactionsRepository(
      cache: transactions,
      remote: _Txns(),
      outbox: () => outbox,
      newId: () => 't${ids++}',
      signedInUserId: () => 'user-1',
    );

    container = ProviderContainer(
      overrides: [
        nowProvider.overrideWithValue(() => now),
        signedInUserIdProvider.overrideWithValue(() => 'user-1'),
        localStoreProvider.overrideWithValue(
          ZadLocalStore(
            outbox: outboxBox,
            transactions: transactions,
            documents: documents,
            chat: documents,
            inventory: documents,
            shopping: documents,
            pharmacy: documents,
            subscriptions: subsBox,
          ),
        ),
        outboxProvider.overrideWithValue(outbox),
        subscriptionsRepositoryProvider.overrideWithValue(subsRepo),
        transactionsRepositoryProvider.overrideWithValue(txns),
        settingsRepositoryProvider.overrideWithValue(
          SettingsRepository(
            cache: documents,
            remote: _NoSettings(),
            outbox: () => outbox,
            signedInUserId: () => 'user-1',
            now: () => now,
          ),
        ),
        budgetRepositoryProvider.overrideWithValue(
          BudgetRepository(
            cache: documents,
            remote: budget,
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

  Future<void> until(bool Function() condition) async {
    for (var i = 0; i < 400; i++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('condition never became true');
  }

  SubscriptionsController controller() =>
      container.read(subscriptionsControllerProvider.notifier);

  test("today is the market's day, not UTC's", () {
    expect(
      container.read(subscriptionsControllerProvider).today,
      DateTime.utc(2026, 9, 22),
    );
  });

  test('marking paid books the expense and moves the renewal on', () async {
    await controller().add(
      title: 'فاتورة كهرباء',
      amount: 420,
      cycle: BillingCycle.monthly,
      renewsOn: DateTime.utc(2026, 9, 25),
      category: 'فواتير',
      type: 'utility',
    );
    final sub = container.read(subscriptionsControllerProvider).items.single;

    final paid = await controller().markPaid(sub);
    expect(paid?.paidFor, DateTime.utc(2026, 9, 25));

    final expense = container
        .read(transactionsRepositoryProvider)
        .allCached()
        .single;
    expect(expense.amount, 420);
    expect(expense.kind, TxnKind.expense);
    // Not the row's own `فواتير`: that is not one of the eleven, and money
    // booked under it lands in a bucket nothing reads.
    expect(expense.category, 'الفواتير');

    final after = container.read(subscriptionsControllerProvider).items.single;
    expect(
      after.nextRenewalFrom(DateTime.utc(2026, 9, 22)),
      DateTime.utc(2026, 10, 25),
    );
  });

  test('the budget is asked again once the change has landed', () async {
    container.read(subscriptionsControllerProvider);
    final before = budget.calls;

    await controller().add(
      title: 'Netflix',
      amount: 150,
      cycle: BillingCycle.monthly,
      renewsOn: DateTime.utc(2026, 9, 25),
    );
    await until(() => budget.calls > before);
    expect(subs.rows, hasLength(1));
  });

  test('...and not while it is still queued', () async {
    subs.offline = true;
    container.read(subscriptionsControllerProvider);
    // Let the build's own refresh fail and settle first.
    await until(
      () => !container.read(subscriptionsControllerProvider).isRefreshing,
    );
    final before = budget.calls;

    await controller().add(
      title: 'Netflix',
      amount: 150,
      cycle: BillingCycle.monthly,
    );
    await until(() => outbox.entries(includeDead: false).single.attempts > 0);
    await pumpEventQueue();
    expect(
      budget.calls,
      before,
      reason: 'a budget asked for before the row landed is the old one',
    );
  });

  test('running rows come first, soonest renewal first', () async {
    await controller().add(
      title: 'later',
      amount: 1,
      cycle: BillingCycle.monthly,
      renewsOn: DateTime.utc(2026, 10, 5),
    );
    await controller().add(
      title: 'sooner',
      amount: 1,
      cycle: BillingCycle.monthly,
      renewsOn: DateTime.utc(2026, 9, 30),
    );
    await controller().add(
      title: 'undated',
      amount: 1,
      cycle: BillingCycle.monthly,
    );
    final stopped = container
        .read(subscriptionsControllerProvider)
        .items
        .firstWhere((s) => s.title == 'later');
    await controller().setActive(stopped, active: false);

    expect(
      container.read(subscriptionsControllerProvider).items.map((s) => s.title),
      <String>['sooner', 'undated', 'later'],
    );
  });

  test('the monthly total spreads yearly and weekly charges', () async {
    await controller().add(title: 'a', amount: 120, cycle: BillingCycle.yearly);
    await controller().add(title: 'b', amount: 50, cycle: BillingCycle.monthly);

    expect(container.read(subscriptionsControllerProvider).monthlyTotal, 60);
  });
}
