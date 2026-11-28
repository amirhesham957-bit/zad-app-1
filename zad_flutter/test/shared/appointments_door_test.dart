// P1.6b (appointments): the page's add, status and delete buttons reach the
// server through the one door, `zad_commit_my_intent`, and never through a
// table write. The remote here is the real one, over a Supabase client whose
// HTTP layer records what leaves.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/sync/sync_failure.dart';
import 'package:zad/features/appointments/data/appointments_repository.dart';

class _Wire {
  final List<http.Request> requests = <http.Request>[];

  /// What the door answers.
  Map<String, dynamic> answer = <String, dynamic>{'ok': true};

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
          <String, dynamic>{'id': 'appt-1', 'user_id': 'user-1'},
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
  late SupabaseAppointmentsRemote remote;

  setUp(() {
    wire = _Wire();
    remote = SupabaseAppointmentsRemote(wire.client);
  });

  test('the add button sends appointment.added with the row id', () async {
    final stored = await remote.insertReturning(<String, dynamic>{
      'id': 'appt-1',
      'user_id': 'user-1',
      'title': 'دكتور أسنان',
      'kind': 'medical',
      'starts_at': '2026-12-01T10:00:00.000Z',
      'place_label': null,
      'remind_minutes_before': 60,
      'recurrence': 'once',
      'status': 'upcoming',
      'source': 'app',
      'for_person': 'أمي',
    });

    final call = wire.doorCalls.single;
    expect(call['p_kind'], 'appointment.added');
    expect(call['p_client_event_id'], 'appointment:appt-1');
    expect(call['p_payload'], <String, dynamic>{
      'item_id': 'appt-1',
      'title': 'دكتور أسنان',
      'kind': 'medical',
      'starts_at': '2026-12-01T10:00:00.000Z',
      'remind_minutes_before': 60,
      'recurrence': 'once',
      'source': 'app',
      'for_person': 'أمي',
    });
    expectTraced(call);
    expect(stored?['id'], 'appt-1');
    expect(wire.tableWrites, isEmpty);
  });

  test('a status button sends a patch of the status alone', () async {
    final stored = await remote.setStatusReturning('appt-1', 'done');
    await remote.setStatusReturning('appt-1', 'done');

    final calls = wire.doorCalls;
    expect(calls.map((c) => c['p_kind']), everyElement('appointment.updated'));
    expect(calls[0]['p_payload'], <String, dynamic>{
      'item_id': 'appt-1',
      'patch': <String, dynamic>{'status': 'done'},
    });
    expectTraced(calls[0]);
    // An absolute write: the second press is its own event, not a replay.
    expect(calls[0]['p_client_event_id'], isNot(calls[1]['p_client_event_id']));
    expect(stored?['id'], 'appt-1');
    expect(wire.tableWrites, isEmpty);
  });

  test('a status on a row that is gone is null, not a failure', () async {
    wire.answer = <String, dynamic>{'ok': false, 'reason': 'item_not_found'};
    expect(await remote.setStatusReturning('appt-1', 'done'), isNull);

    wire.answer = <String, dynamic>{'ok': false, 'reason': 'status_invalid'};
    await expectLater(
      remote.setStatusReturning('appt-1', 'gone'),
      throwsA(isA<ServerRefusal>()),
    );
  });

  test('the delete button sends appointment.deleted, gone is done', () async {
    await remote.remove('appt-1');

    final call = wire.doorCalls.single;
    expect(call['p_kind'], 'appointment.deleted');
    expect(call['p_client_event_id'], 'appointment_delete:appt-1');
    expect(call['p_payload'], <String, dynamic>{'item_id': 'appt-1'});
    expectTraced(call);

    wire.answer = <String, dynamic>{'ok': false, 'reason': 'item_not_found'};
    await remote.remove('appt-1');

    wire.answer = <String, dynamic>{'ok': false, 'reason': 'bad_shape'};
    await expectLater(remote.remove('appt-1'), throwsA(isA<ServerRefusal>()));
    expect(wire.tableWrites, isEmpty);
  });
}
