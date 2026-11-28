// P1.6b (home): the maintenance and documents buttons write through the one
// door, `zad_commit_my_intent`, never to the tables. The wire check runs the
// real helper over a recording client; the source check pins the screens.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/commit_my_intent.dart';
import 'package:zad/core/data/sync/sync_failure.dart';

SupabaseClient _client(List<http.Request> seen, Map<String, dynamic> answer) =>
    SupabaseClient(
      'https://example.supabase.co',
      'anon',
      httpClient: MockClient((request) async {
        seen.add(request);
        return http.Response(
          jsonEncode(answer),
          200,
          headers: <String, String>{'content-type': 'application/json'},
          request: request,
        );
      }),
    );

void main() {
  const screens = <String>[
    'lib/features/maintenance/presentation/maintenance_screen.dart',
    'lib/features/documents/presentation/documents_screen.dart',
  ];

  test('screens write through the door and not to their tables', () {
    for (final path in screens) {
      final source = File(path).readAsStringSync();
      expect(
        RegExp(r'\.(insert|upsert|update|delete)\(').hasMatch(source),
        isFalse,
        reason: '$path still writes to a table',
      );
      expect(source, contains('commitMyIntent('));
    }
    final maintenance = File(screens[0]).readAsStringSync();
    for (final kind in <String>[
      'maintenance.added',
      'maintenance.updated',
      'maintenance.deleted',
    ]) {
      expect(maintenance, contains("'$kind'"));
    }
    final documents = File(screens[1]).readAsStringSync();
    for (final kind in <String>['document.saved', 'document.deleted']) {
      expect(documents, contains("'$kind'"));
    }
  });

  test('a button intent reaches the door with kind, key and trace', () async {
    final seen = <http.Request>[];
    final client = _client(seen, <String, dynamic>{'ok': true});
    await commitMyIntent(
      client,
      kind: 'maintenance.updated',
      clientEventId: 'e1',
      payload: <String, dynamic>{
        'item_id': 'a',
        'patch': <String, dynamic>{'last_service_date': '2026-11-28'},
      },
    );
    expect(seen, hasLength(1));
    expect(seen.single.url.path, endsWith('/rpc/zad_commit_my_intent'));
    final body = jsonDecode(seen.single.body) as Map<String, dynamic>;
    expect(body['p_kind'], 'maintenance.updated');
    expect(body['p_client_event_id'], 'e1');
    expect((body['p_payload'] as Map)['item_id'], 'a');
    expect(body['p_trace_id'], isNotEmpty);
  });

  test('a refusal from the door throws', () async {
    final client = _client(<http.Request>[], <String, dynamic>{
      'ok': false,
      'reason': 'item_not_found',
    });
    expect(
      commitMyIntent(
        client,
        kind: 'document.deleted',
        clientEventId: 'e2',
        payload: <String, dynamic>{'item_id': 'x'},
      ),
      throwsA(isA<ServerRefusal>()),
    );
  });
}
