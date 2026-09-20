/// Talking to `zad-brain`.
///
/// ## About the "streaming"
///
/// `agent_turn_stream` does **not** stream the model. `handleAgentTurnStream`
/// runs the whole of `handleAgentTurn` to completion — routing, memory, tools,
/// review — and only then slices the finished reply into 24-character pieces
/// and emits them as SSE. The wait before the first chunk is the entire turn.
///
/// So the typewriter is a presentation effect, not progress, and this client
/// reproduces it because the Kotlin one does and the two should feel the same
/// — not because it makes the answer arrive sooner. Anything built on top of
/// this that treats the first chunk as "the model has started" would be wrong.
///
/// The server also falls back to plain JSON in three cases it does not
/// announce: a reply under 40 characters, any turn that ran tools, and any
/// error. A client that only handled `text/event-stream` would break on the
/// most important turns — the ones that did something.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/env/zad_env.dart';
import 'package:zad/features/chat/domain/agent_turn.dart';

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
  /// call the model more than once, and the first byte does not arrive until
  /// all of that is done.
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
          // The final frame carries everything but the reply — the server
          // deletes that key before sending it, because the text already went
          // out as chunks.
          meta = AgentTurn.fromJson(<String, dynamic>{
            ...frame,
            'reply': buffer.toString(),
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
