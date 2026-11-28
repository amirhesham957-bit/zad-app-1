// P1.6b (family): the chores, their preferences, the family goal, the spending
// limits, the savings funds and the challenges reach the server through the one
// door, `zad_commit_my_intent`, and never through a table write. The chat and
// the last-seen stamp stay direct (talk and a heartbeat). The remote is the
// real one, over a Supabase client whose HTTP layer records what leaves.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/sync/sync_failure.dart';
import 'package:zad/features/savings/data/family_savings_door.dart';
import 'package:zad/shared/family/data/family_life_remote.dart';

class _Wire {
  final List<http.Request> requests = <http.Request>[];

  Map<String, dynamic> answer = <String, dynamic>{'ok': true};

  late final SupabaseClient client = SupabaseClient(
    'https://example.supabase.co',
    'anon',
    httpClient: MockClient((request) async {
      requests.add(request);
      final isDoor = request.url.path.endsWith('/rpc/zad_commit_my_intent');
      return http.Response(
        jsonEncode(isDoor ? answer : <Map<String, dynamic>>[]),
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
  late FamilyLifeRemote remote;

  setUp(() {
    wire = _Wire();
    remote = FamilyLifeRemote(wire.client);
  });

  void expectDoorOnly(Map<String, dynamic> call, String idPrefix) {
    expect(call['p_trace_id'], matches(RegExp(r'^[A-Za-z0-9_-]{8,64}$')));
    expect(call['p_client_event_id'], startsWith(idPrefix));
    expect(call['p_client_event_id'].toString().length, lessThanOrEqualTo(100));
    expect(call['p_payload'], isNot(contains('user_id')));
    expect(wire.tableWrites, isEmpty);
  }

  test('a chore sends family.chore_added with the reward as reward', () async {
    await remote.addChore(
      familyId: 'fam-1',
      assignedTo: 'mem-1',
      title: 'ترتيب الأوضة',
      dueDate: '2026-11-30',
      reward: 15,
      minutes: 20,
    );

    final call = wire.doorCalls.single;
    expect(call['p_kind'], 'family.chore_added');
    expect(call['p_payload'], <String, dynamic>{
      'family_id': 'fam-1',
      'assigned_to': 'mem-1',
      'title': 'ترتيب الأوضة',
      'due_date': '2026-11-30',
      'reward': 15.0,
      'minutes': 20,
    });
    expectDoorOnly(call, 'family_chore:');
  });

  test('a chore without a date or minutes leaves them out', () async {
    await remote.addChore(familyId: 'fam-1', assignedTo: 'mem-1', title: 'x');

    final payload = wire.doorCalls.single['p_payload'] as Map<String, dynamic>;
    expect(payload.containsKey('due_date'), isFalse);
    expect(payload.containsKey('minutes'), isFalse);
    expect(payload['reward'], 0);
  });

  test('a chore preference sends family.chore_pref_set', () async {
    await remote.saveChorePreference(
      familyId: 'fam-1',
      memberId: 'mem-2',
      minutesPerWeek: 90,
      dislikes: <String>['المواعين'],
      likes: <String>['الزرع'],
    );

    final call = wire.doorCalls.single;
    expect(call['p_kind'], 'family.chore_pref_set');
    expect(call['p_payload'], <String, dynamic>{
      'member_id': 'mem-2',
      'family_id': 'fam-1',
      'minutes_per_week': 90,
      'dislikes': <String>['المواعين'],
      'likes': <String>['الزرع'],
    });
    expectDoorOnly(call, 'family_chore_pref:');
  });

  test(
    'a family goal sends family.goal_added, not a family_goals insert',
    () async {
      await remote.addGoal(
        familyId: 'fam-1',
        target: 2000,
        monthYear: '2026-11',
        reward: 'خروجة',
      );

      final call = wire.doorCalls.single;
      expect(call['p_kind'], 'family.goal_added');
      expect(call['p_payload'], <String, dynamic>{
        'family_id': 'fam-1',
        'target_amount': 2000.0,
        'month_year': '2026-11',
        'reward_suggestion': 'خروجة',
      });
      expectDoorOnly(call, 'family_goal:');
    },
  );

  test('a minor refused by the door surfaces as the door refusal', () async {
    wire.answer = <String, dynamic>{'ok': false, 'reason': 'minor_no_budget'};

    await expectLater(
      remote.addGoal(familyId: 'fam-1', target: 10, monthYear: '2026-12'),
      throwsA(
        isA<ServerRefusal>().having(
          (e) => e.reason,
          'reason',
          'minor_no_budget',
        ),
      ),
    );
    expect(wire.tableWrites, isEmpty);
  });

  test(
    'a reward refused for a non-admin keeps its words in the error',
    () async {
      wire.answer = <String, dynamic>{
        'ok': false,
        'reason': 'only_admins_set_rewards',
      };

      await expectLater(
        remote.addChore(
          familyId: 'fam-1',
          assignedTo: 'mem-1',
          title: 'x',
          reward: 5,
        ),
        throwsA(predicate((e) => '$e'.contains('only_admins_set_rewards'))),
      );
    },
  );

  test(
    'spend limits send both caps, null clears one, and return the row',
    () async {
      wire.answer = <String, dynamic>{
        'ok': true,
        'after': <String, dynamic>{
          'id': 'mem-3',
          'daily_limit': 50.0,
          'weekly_limit': null,
        },
      };

      final row = await remote.setSpendLimits('mem-3', daily: 50);

      final call = wire.doorCalls.single;
      expect(call['p_kind'], 'family.spend_limits_set');
      expect(call['p_payload'], <String, dynamic>{
        'member_id': 'mem-3',
        'daily': 50.0,
        'weekly': null,
      });
      expectDoorOnly(call, 'family_limits:');
      expect(row, <String, dynamic>{
        'id': 'mem-3',
        'daily_limit': 50.0,
        'weekly_limit': null,
      });
    },
  );

  test(
    'spend limits refused for a non-admin read as null, as before',
    () async {
      wire.answer = <String, dynamic>{'ok': false, 'reason': 'admins_only'};

      expect(await remote.setSpendLimits('mem-3', daily: 1, weekly: 1), isNull);
      expect(wire.tableWrites, isEmpty);
    },
  );

  test('another refusal on spend limits is not swallowed', () async {
    wire.answer = <String, dynamic>{'ok': false, 'reason': 'limit_invalid'};

    await expectLater(
      remote.setSpendLimits('mem-3', daily: -1, weekly: 1),
      throwsA(isA<ServerRefusal>()),
    );
  });

  test('a savings fund sends family.fund_added with the season', () async {
    await addFund(
      wire.client,
      familyId: 'fam-1',
      name: 'عيد',
      target: 1000,
      eventId: 'evt-1',
      targetDate: DateTime.utc(2027, 3, 9),
    );

    final call = wire.doorCalls.single;
    expect(call['p_kind'], 'family.fund_added');
    expect(call['p_payload'], <String, dynamic>{
      'family_id': 'fam-1',
      'name': 'عيد',
      'target_amount': 1000.0,
      'event_id': 'evt-1',
      'target_date': '2027-03-09T00:00:00.000Z',
    });
    expectDoorOnly(call, 'family_fund_add:');
  });

  test('a contribution sends the amount, not the new total', () async {
    await contributeToFund(wire.client, 'fund-1', 50);

    final call = wire.doorCalls.single;
    expect(call['p_kind'], 'family.fund_contributed');
    expect(call['p_payload'], <String, dynamic>{
      'fund_id': 'fund-1',
      'amount': 50.0,
    });
    expectDoorOnly(call, 'family_fund_pay:fund-1:');
  });

  test('two presses are two intents with two ids', () async {
    await contributeToFund(wire.client, 'fund-1', 5);
    await contributeToFund(wire.client, 'fund-1', 5);

    final ids = wire.doorCalls.map((c) => c['p_client_event_id']).toSet();
    expect(ids, hasLength(2));
  });

  test('a challenge sends family.challenge_added with its season', () async {
    await addChallenge(
      wire.client,
      familyId: 'fam-1',
      type: 'weekly',
      title: 'تحدي العيد',
      target: 500,
      reward: 25,
      start: DateTime.utc(2026, 11, 28),
      end: DateTime.utc(2026, 12, 5),
      seasonKey: 'eid',
      badge: '🌙',
    );

    final call = wire.doorCalls.single;
    expect(call['p_kind'], 'family.challenge_added');
    expect(call['p_payload'], <String, dynamic>{
      'family_id': 'fam-1',
      'challenge_type': 'weekly',
      'title': 'تحدي العيد',
      'target_amount': 500.0,
      'reward_amount': 25.0,
      'start_date': '2026-11-28T00:00:00.000Z',
      'end_date': '2026-12-05T00:00:00.000Z',
      'season_key': 'eid',
      'badge': '🌙',
    });
    expectDoorOnly(call, 'family_challenge_add:');
  });

  test('chat and last seen stay direct table writes', () async {
    await remote.setPinned('msg-1', pinned: true);
    await remote.touchLastSeen('mem-1');

    expect(wire.doorCalls, isEmpty);
    expect(wire.tableWrites, hasLength(2));
  });
}
