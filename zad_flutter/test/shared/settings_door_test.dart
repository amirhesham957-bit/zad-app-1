// P1.6b (account settings): the ceiling, the salary day, the market and the two
// app flags reach the server through the one door, `zad_commit_my_intent`, and
// never through a `zad_users` upsert. The remote is the real one, over a
// Supabase client whose HTTP layer records what leaves.

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
import 'package:zad/shared/settings/data/settings_repository.dart';

class _Wire {
  final List<http.Request> requests = <http.Request>[];

  Map<String, dynamic> answer = <String, dynamic>{'ok': true};

  /// What the read-back says the row holds.
  Map<String, dynamic> row = <String, dynamic>{};

  late final SupabaseClient client = SupabaseClient(
    'https://example.supabase.co',
    'anon',
    httpClient: MockClient((request) async {
      requests.add(request);
      final isDoor = request.url.path.endsWith('/rpc/zad_commit_my_intent');
      return http.Response(
        jsonEncode(isDoor ? answer : <Map<String, dynamic>>[row]),
        200,
        headers: <String, String>{'content-type': 'application/json'},
        request: request,
      );
    }),
  );

  List<Map<String, dynamic>> get doorCalls => requests
      .where((r) => r.url.path.endsWith('/rpc/zad_commit_my_intent'))
      .map((r) => jsonDecode(r.body) as Map<String, dynamic>)
      .toList();

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
  late SettingsRepository repo;
  final now = DateTime.parse('2026-09-20T09:00:00Z');

  setUp(() async {
    wire = _Wire();
    dir = await Directory.systemTemp.createTemp('zad_settings_door');
    Hive.init(dir.path);
    outbox = Outbox(
      box: await Hive.openBox<String>('outbox'),
      send: (_) async {},
      clock: () => now,
    );
    repo = SettingsRepository(
      cache: await Hive.openBox<String>('cache'),
      remote: SupabaseSettingsRemote(wire.client),
      outbox: () => outbox,
      signedInUserId: () => 'user-1',
      now: () => now,
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  OutboxEntry only() => outbox
      .entries(includeDead: false)
      .singleWhere((e) => e.kind == OutboxKind.updateAccountSettings);

  void expectDoorOnly(Map<String, dynamic> call) {
    expect(call['p_trace_id'], matches(RegExp(r'^[A-Za-z0-9_-]{8,64}$')));
    expect(call['p_client_event_id'], startsWith('settings:'));
    expect(call['p_payload'], isNot(contains('user_id')));
    expect(wire.tableWrites, isEmpty);
  }

  test('the ceiling sends money.limit_set', () async {
    await repo.setMonthlyLimit(8000);
    wire.row = <String, dynamic>{
      'monthly_limit': 8000,
      'limit_confirmed_at': '2026-09-20T09:00:00+00:00',
    };
    await repo.sendQueued(only());

    final call = wire.doorCalls.single;
    expect(call['p_kind'], 'money.limit_set');
    expect(call['p_payload'], <String, dynamic>{'amount': 8000.0});
    expectDoorOnly(call);
  });

  test('the salary day sends cycle_start_set, and null clears', () async {
    await repo.setCycleStartDay(27);
    wire.row = <String, dynamic>{'cycle_start_day': 27};
    await repo.sendQueued(only());
    expect(wire.doorCalls.single['p_kind'], 'settings.cycle_start_set');
    expect(wire.doorCalls.single['p_payload'], <String, dynamic>{'day': 27});
    expectDoorOnly(wire.doorCalls.single);

    wire = _Wire();
    repo = SettingsRepository(
      cache: await Hive.openBox<String>('cache'),
      remote: SupabaseSettingsRemote(wire.client),
      outbox: () => outbox,
      signedInUserId: () => 'user-1',
      now: () => now,
    );
    await repo.setCycleStartDay(null);
    wire.row = <String, dynamic>{'cycle_start_day': null};
    await repo.sendQueued(only());
    expect(wire.doorCalls.single['p_payload'], <String, dynamic>{'day': null});
    expectDoorOnly(wire.doorCalls.single);
  });

  test('the market sends settings.market_set with both codes', () async {
    await repo.setMarket(country: 'SA', currency: 'SAR');
    wire.row = <String, dynamic>{'country': 'SA', 'currency': 'SAR'};
    await repo.sendQueued(only());

    final call = wire.doorCalls.single;
    expect(call['p_kind'], 'settings.market_set');
    expect(call['p_payload'], <String, dynamic>{
      'currency': 'SAR',
      'country': 'SA',
    });
    expectDoorOnly(call);
  });

  test('the pet-calls and food-pattern switches send app_flag_set', () async {
    await repo.setPetCallsEnabled(on: false);
    await repo.sendQueued(only());
    var call = wire.doorCalls.single;
    expect(call['p_kind'], 'settings.app_flag_set');
    expect(call['p_payload'], <String, dynamic>{
      'setting': 'pet_calls',
      'on': false,
    });
    expectDoorOnly(call);

    await outbox.discard(only().id);
    wire.requests.clear();
    await repo.setFoodPatternEnabled(on: true);
    await repo.sendQueued(only());
    call = wire.doorCalls.single;
    expect(call['p_payload'], <String, dynamic>{
      'setting': 'food_pattern',
      'on': true,
    });
    expectDoorOnly(call);
  });

  test('a refusal is permanent and nothing reads back after it', () async {
    await repo.setCycleStartDay(27);
    wire.answer = <String, dynamic>{'ok': false, 'reason': 'cycle_day_invalid'};
    await expectLater(repo.sendQueued(only()), throwsA(isA<ServerRefusal>()));
    expect(wire.requests.where((r) => r.method == 'GET'), isEmpty);
  });
}
