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
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
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

  /// Kotlin's `VoicePersona.values()`, id and `displayNameAr`, in order.
  static const List<(String, String)> all = <(String, String)>[
    (sarahWarm, '👩 سارة (صوت بشري دافئ)'),
    (karimPro, '👨 كريم (صوت بشري واثق)'),
    (petMascot, '🐾 زاد الأليف (رفيق مرح)'),
  ];
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
  new(this._client, this._box);

  final SupabaseClient _client;
  final Box<String> _box;
  int _generation = 0;

  // Kotlin's `zad_voice_persona` preference, `persona_id`.
  static const String _personaKey = 'zad_voice_persona:persona_id';

  /// Whether زاد is talking.
  final ValueNotifier<bool> speaking = ValueNotifier<bool>(false);

  /// Loudness of what is being said, 0..1, for the orb and the wave.
  final ValueNotifier<double> level = ValueNotifier<double>(0);

  /// The chosen persona — the one the voice sheet and the read-aloud use.
  String get persona => _box.get(_personaKey) ?? VoicePersona.sarahWarm;

  set persona(String id) => unawaited(_box.put(_personaKey, id));

  /// Stops whatever is being said (the next chunk will not start).
  void stop() {
    _generation++;
    speaking.value = false;
    level.value = 0;
  }

  /// Says [text] in [persona]'s voice (the chosen one by default).
  Future<void> speak(String text, {String? persona}) async {
    final generation = ++_generation;
    final voice = persona ?? this.persona;
    speaking.value = true;
    try {
      await _speak(text, voice, generation);
    } finally {
      if (generation == _generation) {
        speaking.value = false;
        level.value = 0;
      }
    }
  }

  Future<void> _speak(String text, String persona, int generation) async {
    var cleaned = cleanSpeechText(text);
    if (cleaned.length > 1200) cleaned = cleaned.substring(0, 1200);
    final chunks = [
      for (final c in speechChunks(cleaned)) c.replaceAll('،', '، ... '),
    ];
    for (final chunk in chunks) {
      if (generation != _generation) return;
      final pcm = await _synthesize(chunk, persona);
      if (pcm == null || generation != _generation) return;
      level.value = _loudness(pcm);
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

  /// RMS of 16-bit little-endian PCM, scaled to 0..1.
  static double _loudness(Uint8List pcm) {
    final data = ByteData.sublistView(pcm);
    final n = pcm.length ~/ 2;
    if (n == 0) return 0;
    var sum = 0.0;
    for (var i = 0; i < n; i += 4) {
      final v = data.getInt16(i * 2, Endian.little) / 32768;
      sum += v * v;
    }
    final rms = math.sqrt(sum / (n / 4).ceil());
    return (rms * 3).clamp(0, 1).toDouble();
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
  (ref) => ZadVoice(
    ref.watch(supabaseClientProvider),
    ref.watch(localStoreProvider).device,
  ),
);
