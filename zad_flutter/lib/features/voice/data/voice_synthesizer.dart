/// `zad-core-intelligence`'s `voice_synthesize`: text in, speech out.
///
/// The server walks the Gemini TTS key pool with the persona's voice (Sarah
/// = Aoede, a woman's voice) and, only if every key fails, Azure Speech in
/// the account country's dialect — Salma (`ar-EG-SalmaNeural`) for Egypt.
/// Either way the body is the same raw PCM, and `X-Zad-Voice-Provider` says
/// which one spoke.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/env/zad_env.dart';

/// One synthesized chunk.
typedef SpokenAudio = ({Uint8List pcm, String provider});

/// Text to speech.
abstract interface class VoiceSynthesizer {
  /// The speech for [text], or throws.
  Future<SpokenAudio> synthesize(String text);
}

/// The personas `voice_synthesize` accepts (`_shared/zadVoice.ts`).
enum VoicePersona {
  /// سارة — Aoede on Gemini, a woman's voice on Azure. The default.
  sarah('sarah_warm'),

  /// كريم — Charon on Gemini, the one man's voice.
  karim('karim_pro');

  new(this.wireName);

  /// The `persona` value.
  final String wireName;
}

/// Over plain http: `functions.invoke` decodes the body as text for a
/// content type it does not know, and `audio/pcm` is one.
class SupabaseVoiceSynthesizer implements VoiceSynthesizer {
  /// Creates a synthesizer over a Supabase client.
  const new(
    this._client, {
    this.persona = VoicePersona.sarah,
    http.Client Function()? clientFactory,
  }) : _clientFactory = clientFactory;

  final SupabaseClient _client;
  final http.Client Function()? _clientFactory;

  /// Whose voice.
  final VoicePersona persona;

  /// A Gemini TTS call plus, at worst, the Azure fallback.
  static const Duration timeout = Duration(seconds: 30);

  @override
  Future<SpokenAudio> synthesize(String text) async {
    final client = _clientFactory?.call() ?? http.Client();
    try {
      final response = await client
          .post(
            Uri.parse(
              '${ZadEnv.supabaseUrl}/functions/v1/zad-core-intelligence',
            ),
            headers: <String, String>{
              // voice_synthesize checks the caller's own token; the anon key
              // is refused with 401.
              'Authorization':
                  'Bearer ${_client.auth.currentSession?.accessToken ?? ''}',
              'Content-Type': 'application/json',
              'apikey': ZadEnv.supabaseAnonKey,
            },
            body: jsonEncode(<String, dynamic>{
              'action': 'voice_synthesize',
              'user_id': _client.auth.currentUser?.id,
              'payload': <String, dynamic>{
                'text': text,
                'persona': persona.wireName,
              },
            }),
          )
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw http.ClientException(
          'voice_synthesize answered ${response.statusCode}: '
          '${utf8.decode(response.bodyBytes, allowMalformed: true)}',
        );
      }
      if (response.bodyBytes.isEmpty) {
        throw StateError('voice_synthesize returned no audio');
      }
      return (
        pcm: response.bodyBytes,
        provider: response.headers['x-zad-voice-provider'] ?? 'gemini',
      );
    } finally {
      client.close();
    }
  }
}
