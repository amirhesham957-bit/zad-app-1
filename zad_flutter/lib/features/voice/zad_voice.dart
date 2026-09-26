/// Kotlin's `ZadNaturalVoiceEngine.speakHumanLike`: زاد's human voice, from
/// `voice_synthesize` on zad-core-intelligence (Gemini TTS, Azure as the
/// fallback), 24 kHz 16-bit mono PCM played through the same AudioTrack
/// channel the companion's sounds use.
///
/// Same text preparation as Kotlin: links read as «الرابط», markdown and
/// emoji dropped, at most 1,200 characters, split at sentence ends into
/// chunks of about 200 characters, a pause after each «،». Spoken only on the
/// customer's tap — never on its own.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/env/zad_env.dart';
import 'package:zad/data/providers.dart';

const MethodChannel _channel = MethodChannel('zad/pet_sound');
const int _sampleRate = 24000;

/// Kotlin's `VoicePersona` ids.
abstract final class VoicePersona {
  /// «سارة (صوت بشري دافئ)» — Kotlin's default.
  static const String sarahWarm = 'sarah_warm';

  /// «كريم (صوت بشري واثق)».
  static const String karimPro = 'karim_pro';

  /// «زاد الأليف (رفيق مرح)».
  static const String petMascot = 'pet_mascot';
}

/// Kotlin's `cleanRawText`.
String cleanSpeechText(String raw) => raw
    .replaceAll(RegExp(r'https?://\S+'), 'الرابط')
    .replaceAll(RegExp(r'[#*`_~\[\]()]'), ' ')
    .replaceAll(
      RegExp(
        '[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}]',
        unicode: true,
      ),
      ' ',
    )
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Kotlin's `splitIntoSpeechChunks`: sentences merged up to ~200 chars.
List<String> speechChunks(String text) {
  final sentences = text
      .split(RegExp(r'(?<=[.!؟])\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (sentences.length <= 1) return text.trim().isEmpty ? const [] : [text];
  final merged = <String>[];
  final current = StringBuffer();
  for (final s in sentences) {
    if (current.isNotEmpty && current.length + s.length > 200) {
      merged.add(current.toString().trim());
      current.clear();
    }
    if (current.isNotEmpty) current.write(' ');
    current.write(s);
  }
  if (current.isNotEmpty) merged.add(current.toString().trim());
  return merged;
}

/// The voice.
class ZadVoice {
  /// Creates the voice.
  new(this._client);

  final SupabaseClient _client;
  int _generation = 0;

  /// Stops whatever is being said (the next chunk will not start).
  void stop() => _generation++;

  /// Says [text] in [persona]'s voice.
  Future<void> speak(
    String text, {
    String persona = VoicePersona.sarahWarm,
  }) async {
    final generation = ++_generation;
    var cleaned = cleanSpeechText(text);
    if (cleaned.length > 1200) cleaned = cleaned.substring(0, 1200);
    final chunks = [
      for (final c in speechChunks(cleaned)) c.replaceAll('،', '، ... '),
    ];
    for (final chunk in chunks) {
      if (generation != _generation) return;
      final pcm = await _synthesize(chunk, persona);
      if (pcm == null || generation != _generation) return;
      try {
        await _channel.invokeMethod<void>('play', <String, Object>{
          'pcm': pcm,
          'sampleRate': _sampleRate,
        });
      } on Object {
        return;
      }
      // The channel returns at once; wait out the clip before the next.
      final ms = pcm.length ~/ 2 * 1000 ~/ _sampleRate;
      await Future<void>.delayed(Duration(milliseconds: ms + 80));
    }
  }

  /// One chunk, with Kotlin's single retry on a server error.
  Future<Uint8List?> _synthesize(String text, String persona) async {
    final session = _client.auth.currentSession;
    final userId = _client.auth.currentUser?.id;
    if (session == null || userId == null) return null;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await http.post(
          Uri.parse('${ZadEnv.supabaseUrl}/functions/v1/zad-core-intelligence'),
          headers: <String, String>{
            'Authorization': 'Bearer ${session.accessToken}',
            'apikey': ZadEnv.supabaseAnonKey,
            'Accept': 'audio/pcm',
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode(<String, Object>{
            'action': 'voice_synthesize',
            'user_id': userId,
            'payload': <String, Object>{'text': text, 'persona': persona},
          }),
        );
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          return response.bodyBytes;
        }
        debugPrint('voice attempt ${attempt + 1}: HTTP ${response.statusCode}');
        if (response.statusCode < 500) return null;
      } on Object catch (e) {
        debugPrint('voice attempt ${attempt + 1} failed: $e');
      }
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
    return null;
  }
}

/// The voice.
final zadVoiceProvider = Provider<ZadVoice>(
  (ref) => ZadVoice(ref.watch(supabaseClientProvider)),
);
