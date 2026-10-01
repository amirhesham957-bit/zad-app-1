/// Talking to `zad-brain`.
///
/// ## Streaming
///
/// `agent_turn_stream` streams the model since 2026-10-01 (تشخيص زاد ٢.٢):
/// the turn's first model call is `streamGenerateContent`, and its text goes
/// out as `{t}` frames while it is being written — until the model asks for
/// a tool. So the first chunk now does mean "the model has started", and the
/// voice starts on the first sentence.
///
/// The server's guards still run after the text is written (an unbacked
/// reminder claim, an empty turn, a tool turn's answer), so the final `done`
/// frame carries the turn's `reply`, and that wins over what streamed. When
/// nothing streamed (a tool turn, a fast reply) the server sends the reply as
/// chunks, as it always did. A `done` frame with `ok: false` is a failed turn.
///
/// The server may still answer plain JSON (an older deploy), so both content
/// types are accepted.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/env/zad_env.dart';
import 'package:zad/shared/chat/domain/agent_turn.dart';

/// One message already in the conversation, as the server wants it.
typedef AgentHistoryEntry = ({String role, String text});

/// Something that happened during a turn.
sealed class AgentEvent {
  const new();
}

/// A piece of the reply.
class AgentChunk extends AgentEvent {
  /// Creates a chunk.
  const new(this.text);

  /// The piece, to append to what is already on screen.
  final String text;
}

/// The turn, finished.
class AgentDone extends AgentEvent {
  /// Creates a completion.
  const new(this.turn);

  /// Everything the turn came back with.
  final AgentTurn turn;
}

/// The agent.
abstract interface class AgentRemote {
  /// Runs one turn.
  ///
  /// Emits [AgentChunk]s as text arrives and exactly one [AgentDone] at the
  /// end. Errors on the stream are transport failures; a turn that simply had
  /// nothing to say arrives as an [AgentDone] carrying an empty [AgentTurn].
  Stream<AgentEvent> turn({
    required String message,
    required List<AgentHistoryEntry> history,
    bool voiceMode,
  });

  /// Says yes to a proposal.
  ///
  /// The tool runs on the server, through the same validation any other tool
  /// goes through. The client never writes the row itself — it only answers
  /// the question.
  Future<AgentExecuted> confirm({
    required String tool,
    required Map<String, dynamic> input,
  });
}

/// The real agent.
class SupabaseAgentRemote implements AgentRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client, {http.Client Function()? clientFactory})
    : _clientFactory = clientFactory;

  final SupabaseClient _client;
  final http.Client Function()? _clientFactory;

  /// The agent loop's function. Not `zad-core-intelligence`, which owns vision
  /// and the one-shot text actions.
  static const String function = 'zad-brain';

  /// How long to wait for a turn.
  ///
  /// Generous on purpose: a turn may route to a specialist, run tools, and
  /// call the model more than once before its reply is final.
  static const Duration timeout = Duration(seconds: 90);

  /// How many earlier messages travel with a turn.
  static const int historyLimit = 8;

  @override
  Stream<AgentEvent> turn({
    required String message,
    required List<AgentHistoryEntry> history,
    bool voiceMode = false,
  }) async* {
    final client = _clientFactory?.call() ?? http.Client();

    try {
      final request =
          http.Request(
              'POST',
              Uri.parse('${ZadEnv.supabaseUrl}/functions/v1/$function'),
            )
            ..headers.addAll(<String, String>{
              'Authorization': 'Bearer ${_token()}',
              'Content-Type': 'application/json',
              // Both, in this order. The server decides which it sends and
              // does not say why, so the client has to accept either.
              'Accept': 'text/event-stream, application/json',
              'apikey': ZadEnv.supabaseAnonKey,
            })
            ..body = jsonEncode(<String, dynamic>{
              'action': 'agent_turn_stream',
              'message': message,
              'voice_mode': voiceMode,
              'history': <Map<String, String>>[
                for (final entry in history.take(historyLimit))
                  <String, String>{'role': entry.role, 'text': entry.text},
              ],
            });

      final response = await client.send(request).timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        // Read before throwing. A 401 and a 500 are the same shape to a caller
        // that only sees "the stream failed", and they need different fixes.
        final body = await response.stream.bytesToString();
        throw http.ClientException(
          'agent_turn_stream answered ${response.statusCode}: '
          '${body.substring(0, body.length.clamp(0, 200))}',
        );
      }

      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('text/event-stream')) {
        final body = await response.stream.bytesToString();
        yield AgentDone(_readTurn(body));
        return;
      }

      final buffer = StringBuffer();
      var meta = const AgentTurn(reply: '');
      var sawDone = false;

      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (!line.startsWith('data: ')) continue;
        final frame = _decodeFrame(line.substring(6));
        if (frame == null) continue;

        if (frame['t'] case final String piece) {
          buffer.write(piece);
          yield AgentChunk(piece);
        } else if (frame['done'] == true) {
          sawDone = true;
          if (frame['ok'] == false) {
            throw StateError(
              'agent_turn refused: ${frame['error'] ?? 'no reason'}',
            );
          }
          // The server's final reply wins: a guard may have changed what
          // streamed. An older deploy left it out; then the chunks are it.
          final reply = frame['reply'];
          meta = AgentTurn.fromJson(<String, dynamic>{
            ...frame,
            'reply': reply is String && reply.isNotEmpty
                ? reply
                : buffer.toString(),
          });
        }
      }

      // A stream that ended without its `done` frame is a truncated turn. The
      // text on screen may be a whole sentence and still be half an answer,
      // and any tool receipt or proposal it carried is simply gone.
      if (!sawDone) {
        throw http.ClientException(
          'agent_turn_stream ended after ${buffer.length} characters with no '
          'done frame',
        );
      }

      yield AgentDone(meta);
    } finally {
      if (_clientFactory == null) client.close();
    }
  }

  @override
  Future<AgentExecuted> confirm({
    required String tool,
    required Map<String, dynamic> input,
  }) async {
    final response = await _client.functions.invoke(
      function,
      body: <String, dynamic>{
        'action': 'agent_confirm',
        'tool': tool,
        // Handed back untouched. The server validated this when it built the
        // proposal; changing it here would confirm something other than what
        // the customer was shown.
        'input': input,
        'source': 'confirm',
      },
    );

    final data = response.data;
    if (data is! Map) {
      throw StateError('agent_confirm answered ${data.runtimeType}');
    }

    return AgentExecuted(
      tool: tool,
      summary: (data['summary'] as String?) ?? '',
      ok: data['ok'] as bool? ?? false,
    );
  }

  /// The session's token, or the publishable key before anybody signs in.
  String _token() =>
      _client.auth.currentSession?.accessToken ?? ZadEnv.supabaseAnonKey;

  static AgentTurn _readTurn(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw StateError('agent_turn answered ${decoded.runtimeType}');
    }
    final json = Map<String, dynamic>.from(decoded);
    if (json['ok'] == false) {
      throw StateError('agent_turn refused: ${json['error'] ?? 'no reason'}');
    }
    return AgentTurn.fromJson(json);
  }

  /// A frame the server sent, or null if it was not JSON.
  ///
  /// A malformed frame is skipped rather than failing the turn — one corrupt
  /// chunk costs a few characters, and throwing would throw away a reply that
  /// is otherwise complete.
  static Map<String, dynamic>? _decodeFrame(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } on FormatException {
      return null;
    }
  }
}

/// The agent loop.
final agentRemoteProvider = Provider<AgentRemote>(
  (ref) => SupabaseAgentRemote(ref.watch(supabaseClientProvider)),
);
