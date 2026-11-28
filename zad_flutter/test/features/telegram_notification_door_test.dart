// P1.6b (notification reads): the three switches reach the server through
// `zad_commit_my_intent`, never a `zad_notification_switches` upsert. (The
// Telegram unlink uses the same helper and is covered by the SQL test; its
// remote needs a signed-in client.)

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/sync/sync_failure.dart';
import 'package:zad/features/notification_reads/data/notification_reads_repository.dart';

class _Wire {
  final List<http.Request> requests = <http.Request>[];
  Map<String, dynamic> answer = <String, dynamic>{'ok': true};

  late final SupabaseClient client = SupabaseClient(
    'https://example.supabase.co',
    'anon',
    httpClient: MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode(answer),
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
  test('a switch sends settings.notification_switch_set', () async {
    final wire = _Wire();
    final repo = SupabaseNotificationReadsRepository(
      wire.client,
      () => 'user-1',
    );
    await repo.setSwitch(ReadKind.documentDue, enabled: true);

    final call = wire.doorCalls.single;
    expect(call['p_kind'], 'settings.notification_switch_set');
    expect(call['p_payload'], <String, dynamic>{
      'kind': 'document_due',
      'enabled': true,
    });
    expect(call['p_client_event_id'], startsWith('notif_switch:document_due:'));
    expect(call['p_trace_id'], matches(RegExp(r'^[A-Za-z0-9_-]{8,64}$')));
    expect(call['p_payload'], isNot(contains('user_id')));
    expect(wire.tableWrites, isEmpty);
  });

  test('a refused switch throws', () async {
    final wire = _Wire()
      ..answer = <String, dynamic>{
        'ok': false,
        'reason': 'notification_kind_invalid',
      };
    final repo = SupabaseNotificationReadsRepository(
      wire.client,
      () => 'user-1',
    );
    await expectLater(
      repo.setSwitch(ReadKind.trip, enabled: false),
      throwsA(isA<ServerRefusal>()),
    );
  });
}
