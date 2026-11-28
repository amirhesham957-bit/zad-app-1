// P1.6b (debts, obligations, subscriptions): every button reaches the server
// through the one door, `zad_commit_my_intent`, and never through a table
// write. The remotes here are the real ones, over a Supabase client whose HTTP
// layer records what leaves.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/sync/sync_failure.dart';
import 'package:zad/features/debts/data/debts_door.dart';
import 'package:zad/features/obligations/data/obligations_repository.dart';
import 'package:zad/shared/subscriptions/data/subscriptions_remote.dart';

class _Wire {
  final List<http.Request> requests = <http.Request>[];

  /// What the door answers.
  Map<String, dynamic> answer = <String, dynamic>{'ok': true};

  /// Whether the row is already on the server (the existence check and the
  /// read-back both see it).
  bool rowExists = false;

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
      return http.Response(
        jsonEncode(<Map<String, dynamic>>[
          if (rowExists) <String, dynamic>{'id': 'row-1', 'user_id': 'user-1'},
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

void expectTraced(Map<String, dynamic> call) {
  expect(call['p_trace_id'], matches(RegExp(r'^[A-Za-z0-9_-]{8,64}$')));
  expect(call['p_payload'], isNot(contains('user_id')));
}

void main() {
  late _Wire wire;

  setUp(() => wire = _Wire());

  group('debts', () {
    test('the add button sends debt.added', () async {
      await addDebt(wire.client, <String, dynamic>{
        'name': 'قرض',
        'principal_amount': 5000.0,
        'remaining_balance': 5000.0,
        'interest_rate': 12.0,
        'minimum_payment': 400.0,
      });

      final call = wire.doorCalls.single;
      expect(call['p_kind'], 'debt.added');
      expect(call['p_client_event_id'], startsWith('debt_add:'));
      expect(call['p_payload'], <String, dynamic>{
        'name': 'قرض',
        'remaining_balance': 5000.0,
        'minimum_payment': 400.0,
        'interest_rate': 12.0,
      });
      expectTraced(call);
      expect(wire.tableWrites, isEmpty);
    });

    test(
      'the pay button sends debt.updated and never goes below zero',
      () async {
        await setDebtBalance(wire.client, 'debt-1', 4000);
        await setDebtBalance(wire.client, 'debt-1', -50);

        final calls = wire.doorCalls;
        expect(calls.map((c) => c['p_kind']), everyElement('debt.updated'));
        expect(calls[0]['p_payload'], <String, dynamic>{
          'item_id': 'debt-1',
          'patch': <String, dynamic>{'remaining_balance': 4000},
        });
        expect(
          ((calls[1]['p_payload'] as Map)['patch'] as Map)['remaining_balance'],
          0,
        );
        // An absolute write: two payments are two events, not a replay.
        expect(
          calls[0]['p_client_event_id'],
          isNot(calls[1]['p_client_event_id']),
        );
        expectTraced(calls[0]);
        expect(wire.tableWrites, isEmpty);
      },
    );

    test(
      'the delete button sends debt.deleted, a missing row is done',
      () async {
        await deleteDebt(wire.client, 'debt-1');
        final call = wire.doorCalls.single;
        expect(call['p_kind'], 'debt.deleted');
        expect(call['p_client_event_id'], 'debt_delete:debt-1');
        expect((call['p_payload'] as Map)['item_id'], 'debt-1');
        expectTraced(call);

        wire.answer = <String, dynamic>{
          'ok': false,
          'reason': 'item_not_found',
        };
        await deleteDebt(wire.client, 'gone');
        expect(wire.tableWrites, isEmpty);
      },
    );

    test('a refusal throws so the screen can say it failed', () async {
      wire.answer = <String, dynamic>{'ok': false, 'reason': 'amount_over_cap'};
      await expectLater(
        addDebt(wire.client, <String, dynamic>{'name': 'x'}),
        throwsA(isA<ServerRefusal>()),
      );
    });
  });

  group('obligations', () {
    Map<String, dynamic> row() => <String, dynamic>{
      'id': 'row-1',
      'user_id': 'user-1',
      'title': 'إيجار',
      'amount': 3000.0,
      'kind': 'rent',
      'due_day': 5,
      'due_date': null,
      'recurrence': 'monthly',
      'confirmed': true,
      'active': true,
    };

    test('a new row is obligation.added with its own id', () async {
      await SupabaseObligationsRemote(wire.client).upsertReturning(row());

      final call = wire.doorCalls.single;
      expect(call['p_kind'], 'obligation.added');
      expect(call['p_client_event_id'], 'obligation:row-1');
      final payload = call['p_payload'] as Map;
      expect(payload['item_id'], 'row-1');
      expect(payload['title'], 'إيجار');
      expect(payload['due_day'], 5);
      expect(payload, isNot(contains('due_date')));
      expect(payload, isNot(contains('active')));
      expectTraced(call);
      expect(wire.tableWrites, isEmpty);
    });

    test('a known row is obligation.updated, with the whole patch', () async {
      wire.rowExists = true;
      await SupabaseObligationsRemote(wire.client)
          .upsertReturning(<String, dynamic>{...row(), 'amount': 3500.0});

      final call = wire.doorCalls.single;
      expect(call['p_kind'], 'obligation.updated');
      final payload = call['p_payload'] as Map;
      expect(payload['item_id'], 'row-1');
      final patch = payload['patch'] as Map;
      expect(patch['amount'], 3500);
      expect(patch['due_date'], isNull);
      expect(patch.containsKey('due_date'), isTrue);
      expect(patch['active'], true);
      expect(patch, isNot(contains('id')));
      expect(patch, isNot(contains('user_id')));
      expectTraced(call);
      expect(wire.tableWrites, isEmpty);
    });

    test('a new row that is already stopped is added, then stopped', () async {
      await SupabaseObligationsRemote(wire.client)
          .upsertReturning(<String, dynamic>{...row(), 'active': false});

      expect(wire.doorCalls.map((c) => c['p_kind']), <String>[
        'obligation.added',
        'obligation.updated',
      ]);
    });

    test(
      'the delete button is obligation.deleted, a missing row is done',
      () async {
        final remote = SupabaseObligationsRemote(wire.client);
        await remote.remove('row-1');
        final call = wire.doorCalls.single;
        expect(call['p_kind'], 'obligation.deleted');
        expect(call['p_client_event_id'], 'obligation_delete:row-1');
        expect((call['p_payload'] as Map)['item_id'], 'row-1');
        expectTraced(call);

        wire.answer = <String, dynamic>{
          'ok': false,
          'reason': 'item_not_found',
        };
        await remote.remove('gone');
        expect(wire.tableWrites, isEmpty);
      },
    );

    test('a refusal is permanent', () async {
      wire.answer = <String, dynamic>{
        'ok': false,
        'reason': 'obligation_title_invalid',
      };
      await expectLater(
        SupabaseObligationsRemote(wire.client).upsertReturning(row()),
        throwsA(isA<ServerRefusal>()),
      );
    });
  });

  group('subscriptions', () {
    Map<String, dynamic> row() => <String, dynamic>{
      'id': 'row-1',
      'user_id': 'user-1',
      'title': 'نتفلكس',
      'amount': 150.0,
      'renewal_date': '2026-12-01',
      'due_day': null,
      'billing_cycle': 'MONTHLY',
      'category': 'ترفيه',
      'type': 'subscription',
      'provider': null,
      'is_active': true,
      'auto_deduct': false,
    };

    test('a new row is subscription.added with its own id', () async {
      await SupabaseSubscriptionsRemote(wire.client).upsertReturning(row());

      final call = wire.doorCalls.single;
      expect(call['p_kind'], 'subscription.added');
      expect(call['p_client_event_id'], 'subscription:row-1');
      final payload = call['p_payload'] as Map;
      expect(payload['item_id'], 'row-1');
      expect(payload['billing_cycle'], 'MONTHLY');
      expect(payload['auto_deduct'], false);
      expect(payload, isNot(contains('provider')));
      expectTraced(call);
      expect(wire.tableWrites, isEmpty);
    });

    test('a known row is subscription.updated, nulls clear a field', () async {
      wire.rowExists = true;
      await SupabaseSubscriptionsRemote(wire.client).upsertReturning(
        <String, dynamic>{...row(), 'is_active': false, 'category': null},
      );

      final call = wire.doorCalls.single;
      expect(call['p_kind'], 'subscription.updated');
      final patch = (call['p_payload'] as Map)['patch'] as Map;
      expect(patch['is_active'], false);
      expect(patch.containsKey('category'), isTrue);
      expect(patch['category'], isNull);
      expect(patch, isNot(contains('id')));
      expect(patch, isNot(contains('user_id')));
      expectTraced(call);
      expect(wire.tableWrites, isEmpty);
    });

    test('the delete button is subscription.deleted', () async {
      await SupabaseSubscriptionsRemote(wire.client).remove('row-1');

      final call = wire.doorCalls.single;
      expect(call['p_kind'], 'subscription.deleted');
      expect(call['p_client_event_id'], 'subscription_delete:row-1');
      expectTraced(call);
      expect(wire.tableWrites, isEmpty);
    });
  });
}
