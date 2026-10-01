// agent_turn_stream: chunks as the model writes them, and the server's final
// reply winning over what streamed (تشخيص زاد ٢.٢).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/shared/chat/data/agent_remote.dart';

String _sse(List<Map<String, Object?>> frames) =>
    frames.map((f) => 'data: ${jsonEncode(f)}\n\n').join();

SupabaseAgentRemote _remote(String body, {String type = 'text/event-stream'}) =>
    SupabaseAgentRemote(
      SupabaseClient('https://example.supabase.co', 'anon'),
      clientFactory: () => MockClient.streaming(
        (request, _) async => http.StreamedResponse(
          Stream<List<int>>.value(utf8.encode(body)),
          200,
          headers: <String, String>{'content-type': type},
        ),
      ),
    );

Future<List<AgentEvent>> _events(SupabaseAgentRemote remote) =>
    remote.turn(message: 'أهلاً', history: const []).toList();

void main() {
  test('chunks arrive in order and the done frame closes the turn', () async {
    final events = await _events(
      _remote(
        _sse(<Map<String, Object?>>[
          <String, Object?>{'t': 'أهلاً '},
          <String, Object?>{'t': 'يا فندم'},
          <String, Object?>{'done': true, 'ok': true, 'reply': 'أهلاً يا فندم'},
        ]),
      ),
    );
    expect(
      events.whereType<AgentChunk>().map((c) => c.text).join(),
      'أهلاً يا فندم',
    );
    expect((events.last as AgentDone).turn.reply, 'أهلاً يا فندم');
  });

  test("the server's final reply wins over what streamed", () async {
    final events = await _events(
      _remote(
        _sse(<Map<String, Object?>>[
          <String, Object?>{'t': 'فكّرتك الساعة ٧'},
          <String, Object?>{
            'done': true,
            'ok': true,
            'reply': 'لسه ماسجلتش التذكير',
          },
        ]),
      ),
    );
    expect((events.last as AgentDone).turn.reply, 'لسه ماسجلتش التذكير');
  });

  test(
    'an older deploy without reply in done: the chunks are the reply',
    () async {
      final events = await _events(
        _remote(
          _sse(<Map<String, Object?>>[
            <String, Object?>{'t': 'تمام'},
            <String, Object?>{'done': true, 'ok': true},
          ]),
        ),
      );
      expect((events.last as AgentDone).turn.reply, 'تمام');
    },
  );

  test('a done frame with ok false is a failed turn', () async {
    await expectLater(
      _events(
        _remote(
          _sse(<Map<String, Object?>>[
            <String, Object?>{
              'done': true,
              'ok': false,
              'error': 'turn_failed',
            },
          ]),
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('plain JSON is still a turn', () async {
    final events = await _events(
      _remote(
        jsonEncode(<String, Object?>{'ok': true, 'reply': 'سجلتها'}),
        type: 'application/json',
      ),
    );
    expect((events.single as AgentDone).turn.reply, 'سجلتها');
  });
}
