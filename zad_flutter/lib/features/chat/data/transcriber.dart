/// Turning a clip into words.
///
/// The transcript goes into the composer and nowhere else. It is not routed
/// into a second executor, and that is deliberate: `voice_agent` also returns
/// `action` and `data` from its own intent schema, which is a parallel way of
/// recording an expense that would sit beside the agent loop and double-write
/// what the agent already does. Only `transcript` is read here; the words then
/// go through exactly the same turn a typed message does.
///
/// The cost of that is one wasted `callJsonModel` per voice message, because
/// `voice_agent` parses intent whether or not anybody wants it. A
/// transcript-only action on `zad-core-intelligence` — `transcribeAudio` is
/// already a standalone function there — would remove it, and this interface
/// is the seam where that swap happens without touching a screen.
library;

import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/features/chat/data/voice_recorder.dart';

/// Reads speech.
abstract interface class Transcriber {
  /// Returns what was said, or null when the clip held no words.
  ///
  /// Throws on transport failure, which the caller tells apart from silence:
  /// one is worth a message about the network, the other is worth "say that
  /// again".
  Future<String?> transcribe(VoiceClip clip);
}

/// The real transcriber, over Groq's Whisper on the server.
class SupabaseTranscriber implements Transcriber {
  /// Creates a transcriber over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  /// The function that owns `transcribeAudio`.
  static const String function = 'zad-core-intelligence';

  @override
  Future<String?> transcribe(VoiceClip clip) async {
    final response = await _client.functions.invoke(
      function,
      body: <String, dynamic>{
        'action': 'voice_agent',
        'payload': <String, dynamic>{
          'audio_base64': base64Encode(clip.bytes),
          'mime_type': clip.mimeType,
        },
      },
    );

    final data = response.data;
    if (data is! Map) {
      throw StateError('voice_agent answered ${data.runtimeType}');
    }

    final transcript = (data['transcript'] as String?)?.trim();
    return (transcript == null || transcript.isEmpty) ? null : transcript;
  }
}
