// P1.6b (money): every money button reaches the server through the one door,
// `zad_commit_my_intent`, and never through a table write. The remotes here are
// the real ones, over a Supabase client whose HTTP layer records what leaves.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/sync/outbox.dart';
import 'package:zad/core/data/sync/outbox_entry.dart';
import 'package:zad/core/data/sync/sync_failure.dart';
import 'package:zad/features/intelligence/data/emergency_fund_remote.dart';
import 'package:zad/shared/budget/data/category_budgets_remote.dart';
import 'package:zad/shared/budget/data/category_budgets_store.dart';
import 'package:zad/shared/transactions/data/transactions_remote.dart';
import 'package:zad/shared/transactions/data/transactions_repository.dart';
import 'package:zad/shared/transactions/domain/transaction.dart';

class _Wire {
  final List<http.Request> requests = <http.Request>[];

  /// What the door answers.
  Map<String, dynamic> answer = <String, dynamic>{'ok': true};

  /// Whether the read-back finds the row.
  bool rowExists = true;

  /// What the read-back says the row holds.
  String rowTitle = 'قهوة';
  String? rowCategory;

  late final SupabaseClient client = SupabaseClient(
    'https://example.supabase.co',
    'anon',
    httpClient: MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/rpc/zad_commit_my_intent')) {
        return http.Response(
          jsonEncode(answer),
          200,
          headers: <String, String>{'content-type': 'application/json'},
          request: request,
        );
      }
      // The read-back of a row.
      return http.Response(
        jsonEncode(<Map<String, dynamic>>[
          if (rowExists)
            <String, dynamic>{
              'id': 'txn-1',
              'user_id': 'user-1',
              'amount': 50,
              'title': rowTitle,
              'category': rowCategory,
              'created_at': '2026-09-19T12:00:00Z',
              'wallet': 'cash',
              'txn_kind': 'expense',
              'is_expense': true,
            },
        ]),
        200,
        headers: <String, String>{'content-type': 'application/json'},
        request: request,
      );
    }),
  );

  /// The intents that went through the door, as sent.
  List<Map<String, dynamic>> get doorCalls => requests
      .where((r) => r.url.path.endsWith('/rpc/zad_commit_my_intent'))
      .map((r) => jsonDecode(r.body) as Map<String, dynamic>)
      .toList();

  /// Writes that bypassed the door: anything but a GET to a table.
  List<String> get tableWrites => requests
      .where(
        (r) =>
            !r.url.path.contains('/rpc/') &&
            !r.url.path.contains('/auth/') &&
            r.method != 'GET' &&
            r.method != 'HEAD',
      )
      .map((r) => '${r.method} ${r.url.path}')
      .toList();
}

void main() {
  late _Wire wire;
  late Directory dir;
  late Outbox outbox;

  setUp(() async {
    wire = _Wire();
    dir = await Directory.systemTemp.createTemp('zad_money_door');
    Hive.init(dir.path);
    outbox = Outbox(
      box: await Hive.openBox<String>('outbox'),
      send: (_) async {},
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  void expectTraced(Map<String, dynamic> call) {
    expect(call['p_trace_id'], matches(RegExp(r'^[A-Za-z0-9_-]{8,64}$')));
    expect(call['p_payload'], isNot(contains('user_id')));
  }

  group('transactions', () {
    late TransactionsRepository repo;

    setUp(() async {
      repo = TransactionsRepository(
        cache: await Hive.openBox<String>('cache'),
        remote: SupabaseTransactionsRemote(wire.client),
        outbox: () => outbox,
        newId: () => 'txn-1',
        signedInUserId: () => 'user-1',
      );
    });

    ZadTransaction coffee(String id) => ZadTransaction.expense(
      id: id,
      userId: 'user-1',
      amount: 50,
      title: 'قهوة',
      createdAt: DateTime.utc(2026, 9, 19, 12),
      wallet: Wallet.cash,
    );

    OutboxEntry only(String kind) =>
        outbox.entries(includeDead: false).singleWhere((e) => e.kind == kind);

    test('the add button sends money.logged with the row id', () async {
      final txn = await repo.record(coffee);
      await repo.sendQueued(only(OutboxKind.insertTransaction));

      final call = wire.doorCalls.single;
      expect(call['p_kind'], 'money.logged');
      expect(call['p_client_event_id'], 'txn:${txn.id}');
      expect((call['p_payload'] as Map)['item_id'], txn.id);
      expect((call['p_payload'] as Map)['title'], 'قهوة');
      expectTraced(call);
      expect(wire.tableWrites, isEmpty);
    });

    test('the edit button sends money.updated, never a table update', () async {
      final txn = (await repo.record(coffee)).markPending(pending: false);
      await outbox.discard(txn.id);
      wire
        ..rowTitle = 'قهوة ٢'
        ..rowCategory = 'مطاعم';
      await repo.edit(txn, title: 'قهوة ٢', amount: 60, category: 'مطاعم');
      await repo.sendQueuedEdit(only(OutboxKind.updateTransaction));

      final call = wire.doorCalls.single;
      expect(call['p_kind'], 'money.updated');
      final payload = call['p_payload'] as Map;
      expect(payload['item_id'], txn.id);
      expect((payload['patch'] as Map)['amount'], 60);
      expect((payload['patch'] as Map)['title'], 'قهوة ٢');
      expectTraced(call);
      expect(wire.tableWrites, isEmpty);
    });

    test('the delete button sends money.deleted', () async {
      final txn = (await repo.record(coffee)).markPending(pending: false);
      await outbox.discard(txn.id);
      await repo.delete(txn.id);
      wire.rowExists = false;
      await repo.sendQueuedDelete(only(OutboxKind.deleteTransaction));

      final call = wire.doorCalls.single;
      expect(call['p_kind'], 'money.deleted');
      expect(call['p_client_event_id'], 'txn_delete:${txn.id}');
      expect((call['p_payload'] as Map)['item_id'], txn.id);
      expectTraced(call);
      expect(wire.tableWrites, isEmpty);
    });

    test('a refusal is permanent, a missing row on delete is done', () async {
      wire.answer = <String, dynamic>{'ok': false, 'reason': 'title_invalid'};
      final remote = SupabaseTransactionsRemote(wire.client);
      await expectLater(
        remote.upsertReturning(<String, dynamic>{'id': 'x', 'title': ''}),
        throwsA(isA<ServerRefusal>()),
      );
      wire.answer = <String, dynamic>{'ok': false, 'reason': 'item_not_found'};
      await remote.delete('gone');
      expect(
        await remote.updateReturning(<String, dynamic>{'id': 'gone'}),
        isNull,
      );
    });
  });

  group('category ceilings', () {
    late CategoryBudgetsStore store;

    setUp(() async {
      store = CategoryBudgetsStore(
        cache: await Hive.openBox<String>('documents'),
        remote: () => SupabaseCategoryBudgetsRemote(wire.client),
        outbox: () => outbox,
        userId: () => 'user-1',
      );
    });

    test('setting a ceiling sends money.category_budget_set', () async {
      await store.write('الترفيه', 300);
      await store.sendQueued(outbox.entries(includeDead: false).single);

      final call = wire.doorCalls.single;
      expect(call['p_kind'], 'money.category_budget_set');
      expect(call['p_payload'], <String, dynamic>{
        'category': 'الترفيه',
        'amount': 300.0,
      });
      expectTraced(call);
      expect(wire.tableWrites, isEmpty);
    });

    test('removing a ceiling sends the same intent with zero', () async {
      await store.write('الترفيه', 0);
      await store.sendQueued(outbox.entries(includeDead: false).single);

      final call = wire.doorCalls.single;
      expect(call['p_kind'], 'money.category_budget_set');
      expect((call['p_payload'] as Map)['amount'], 0);
      expect(wire.tableWrites, isEmpty);
    });

    test('removing one that is already gone is not an error', () async {
      wire.answer = <String, dynamic>{
        'ok': false,
        'reason': 'no_category_budget',
      };
      await store.write('الترفيه', 0);
      await store.sendQueued(outbox.entries(includeDead: false).single);
      expect(wire.doorCalls, hasLength(1));
    });
  });

  test('the emergency fund save sends settings.emergency_fund_set', () async {
    await writeEmergencyFund(wire.client, 1200);

    final call = wire.doorCalls.single;
    expect(call['p_kind'], 'settings.emergency_fund_set');
    expect(call['p_payload'], <String, dynamic>{'balance': 1200.0});
    expectTraced(call);
    expect(wire.tableWrites, isEmpty);
  });
}
