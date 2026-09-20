// The screen's side of setting a budget.
//
// What matters here is the honesty of the two states the customer sees. A
// value typed with no signal is *saved* — it is on the phone and in the queue —
// and the screen has to say both halves: saved, not sent. The controller is
// what draws that line, so these pin it from both directions.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/local/boxes.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/features/budget/data/budget_repository.dart';
import 'package:zad/features/settings/application/settings_controller.dart';
import 'package:zad/features/settings/data/settings_repository.dart';
import 'package:zad/features/transactions/data/transactions_remote.dart';
import 'package:zad/features/transactions/data/transactions_repository.dart';

/// Refuses at once, so nothing in these tests waits on a budget fetch.
class _OfflineBudget implements BudgetRemote {
  @override
  Future<Map<String, dynamic>> fetch({
    required String userId,
    required String timeZone,
  }) => Future<Map<String, dynamic>>.error(const SocketException('offline'));
}

class _NoTransactions implements TransactionsRemote {
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

class _FakeSettingsRemote implements SettingsRemote {
  Map<String, dynamic>? row = <String, dynamic>{};
  Exception? failWith;
  int upserts = 0;

  /// Answers the upsert without error and then has no row to show for it —
  /// the 200-that-changed-nothing the repository reads back to catch.
  bool swallowsWrites = false;

  @override
  Future<Map<String, dynamic>?> fetch({required String userId}) async {
    if (failWith case final e?) throw e;
    return row;
  }

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> sent,
  ) async {
    upserts++;
    if (failWith case final e?) throw e;
    if (swallowsWrites) return null;
    final next = <String, dynamic>{...?row};
    for (final entry in sent.entries) {
      if (entry.key == 'id') continue;
      next[entry.key] = entry.value;
    }
    row = next;
    return next;
  }
}

void main() {
  late Directory dir;
  late Box<String> documents;
  late Box<String> transactions;
  late Box<String> outboxBox;
  late _FakeSettingsRemote remote;

  final now = DateTime.parse('2026-09-20T09:00:00Z');

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_settings_ctrl_test');
    Hive.init(dir.path);
    documents = await Hive.openBox<String>('documents');
    transactions = await Hive.openBox<String>('transactions');
    outboxBox = await Hive.openBox<String>('outbox');
    remote = _FakeSettingsRemote();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  ProviderContainer containerWith() {
    late SettingsRepository settings;
    late TransactionsRepository txns;

    final outbox = Outbox(
      box: outboxBox,
      send: (entry) => settings.sendQueued(entry),
      clock: () => now,
    );
    settings = SettingsRepository(
      cache: documents,
      remote: remote,
      outbox: () => outbox,
      signedInUserId: () => 'user-1',
      now: () => now,
    );
    txns = TransactionsRepository(
      cache: transactions,
      remote: _NoTransactions(),
      outbox: () => outbox,
      newId: () => 'txn',
      signedInUserId: () => 'user-1',
    );

    return ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(
          ZadLocalStore(
            outbox: outboxBox,
            transactions: transactions,
            documents: documents,
            chat: documents,
          ),
        ),
        nowProvider.overrideWithValue(() => now),
        outboxProvider.overrideWithValue(outbox),
        settingsRepositoryProvider.overrideWithValue(settings),
        transactionsRepositoryProvider.overrideWithValue(txns),
        budgetRepositoryProvider.overrideWithValue(
          BudgetRepository(
            cache: documents,
            remote: _OfflineBudget(),
            signedInUserId: () => 'user-1',
          ),
        ),
      ],
    );
  }

  test('opens with what is already on the device', () async {
    await documents.put(
      'account_settings',
      jsonEncode(<String, dynamic>{'monthly_limit': 8000}),
    );
    final container = containerWith();
    addTearDown(container.dispose);

    // Read synchronously, in the same turn the provider is first watched —
    // the settings row must not flash empty before the cache arrives.
    final view = container.read(settingsControllerProvider);

    expect(view.settings?.monthlyLimit, 8000);
    expect(view.hasUnsentChanges, isFalse);
  });

  test('a saved limit reaches the server and leaves nothing queued', () async {
    final container = containerWith();
    addTearDown(container.dispose);
    final controller = container.read(settingsControllerProvider.notifier);

    expect(await controller.setMonthlyLimit(8000), isTrue);

    final view = container.read(settingsControllerProvider);
    expect(view.settings?.monthlyLimit, 8000);
    expect(view.isSaving, isFalse);
    expect(view.hasUnsentChanges, isFalse);
    expect(remote.row?['monthly_limit'], 8000);
  });

  test('with no signal it is saved on the phone and says so', () async {
    remote.failWith = const SocketException('offline');
    final container = containerWith();
    addTearDown(container.dispose);
    final controller = container.read(settingsControllerProvider.notifier);

    // True: the value *was* saved. Reporting failure here would be wrong —
    // the number is on the device and the queue will carry it.
    expect(await controller.setMonthlyLimit(8000), isTrue);

    final view = container.read(settingsControllerProvider);
    expect(view.settings?.monthlyLimit, 8000);
    expect(
      view.hasUnsentChanges,
      isTrue,
      reason: 'the screen has to say the server does not have it yet',
    );
    expect(view.queuedWrites, 1);
  });

  test('a write the server silently ignored stays queued', () async {
    // Not an exception — a 200 that changed nothing, which is the failure the
    // repository reads the row back to catch. The controller must not report
    // it as settled either.
    final container = containerWith();
    addTearDown(container.dispose);
    final controller = container.read(settingsControllerProvider.notifier);

    remote.swallowsWrites = true;
    await controller.setMonthlyLimit(8000);

    expect(container.read(settingsControllerProvider).hasUnsentChanges, isTrue);
  });

  test('the salary day is saved the same way', () async {
    final container = containerWith();
    addTearDown(container.dispose);
    final controller = container.read(settingsControllerProvider.notifier);

    expect(await controller.setCycleStartDay(25), isTrue);

    expect(
      container.read(settingsControllerProvider).settings?.cycleStartDay,
      25,
    );
    expect(remote.row?['cycle_start_day'], 25);
  });

  test('a refresh failure keeps the figures that were on screen', () async {
    await documents.put(
      'account_settings',
      jsonEncode(<String, dynamic>{'monthly_limit': 8000}),
    );
    remote.failWith = const SocketException('offline');

    final container = containerWith();
    addTearDown(container.dispose);
    container.read(settingsControllerProvider);

    await container
        .read(settingsControllerProvider.notifier)
        .refresh(force: true);

    final view = container.read(settingsControllerProvider);
    expect(view.settings?.monthlyLimit, 8000);
    expect(view.error, isNotNull);
  });
}
