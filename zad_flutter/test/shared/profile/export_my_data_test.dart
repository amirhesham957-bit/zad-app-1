// «تصدير بياناتي» (ZAD_PLAN ٨.٣): the profile row asks `zad_export_my_data`
// and shares what comes back as a JSON file.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/shared/profile/application/profile_controller.dart';

SupabaseClient _client(
  http.Response Function(http.Request) answer,
  List<String> paths,
) => SupabaseClient(
  'https://example.supabase.co',
  'anon',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
  httpClient: MockClient((request) async {
    paths.add(request.url.path);
    final r = answer(request);
    // postgrest reads the request back off the response.
    return http.Response.bytes(
      r.bodyBytes,
      r.statusCode,
      headers: r.headers,
      request: request,
    );
  }),
);

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test(
    'the export is the server answer, indented, from the export RPC',
    () async {
      final paths = <String>[];
      final out = await fetchMyDataExport(
        _client(
          (_) => _json(<String, Object>{
            'user_id': 'u1',
            'data': <String, Object>{
              'zad_transactions': <Object>[
                <String, Object>{'amount': 50, 'title': 'قهوة'},
              ],
            },
          }),
          paths,
        ),
      );
      expect(paths, <String>['/rest/v1/rpc/zad_export_my_data']);
      expect(out, isNotNull);
      expect(out, contains('zad_transactions'));
      expect(out, contains('قهوة'));
      expect(out, contains('\n  '), reason: 'indented, readable');
      expect(jsonDecode(out!), isA<Map<String, dynamic>>());
    },
  );

  test('a refused or broken answer is no file', () async {
    final paths = <String>[];
    expect(
      await fetchMyDataExport(
        _client(
          (_) => _json(<String, String>{
            'message': 'not signed in',
            'code': '42501',
          }, 403),
          paths,
        ),
      ),
      isNull,
    );
    expect(
      await fetchMyDataExport(_client((_) => _json(<Object>[]), paths)),
      isNull,
    );
  });
}
