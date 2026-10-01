/// The short lines زاد says the moment a spoken question is sent, while the
/// answer is still being thought and synthesized.
///
/// A spoken turn is transcription, the brain and then Gemini TTS, one after
/// the other: on 2026-09-30 the first sentence of an answer reached the phone
/// 10–12 s after the customer let go of the mic (function logs), and the
/// owner read that silence as «مش شغال». Words said at once in her own voice
/// say "I heard you" while the rest takes the time it takes.
///
/// The lines are synthesized once, through the same `voice_synthesize` as
/// every answer, and kept on the device. Until they are kept there is no
/// opener: never a wait on the network, and never a robotic voice.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:zad/shared/voice/data/voice_synthesizer.dart';

/// What زاد says first. Short, so each is a second of audio, and in words
/// every Arabic dialect reads the same. Sent to the voice as they are: data
/// for the synthesizer as much as UI text.
const List<String> voiceOpenerLines = <String>[
  'لحظة واحدة…',
  'حاضر، ثواني…',
  'تمام، لحظة…',
];

/// Where the synthesized lines are kept.
abstract interface class VoiceOpenerStore {
  /// The kept audio under [key], or null.
  Future<Uint8List?> read(String key);

  /// Keeps [pcm] under [key].
  Future<void> write(String key, Uint8List pcm);
}

/// In the app's support directory, one raw PCM file per line.
class FileVoiceOpenerStore implements VoiceOpenerStore {
  /// Creates the store.
  const new();

  Future<File> _file(String key) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/voice_openers/$key.pcm');
  }

  @override
  Future<Uint8List?> read(String key) async {
    final file = await _file(key);
    if (!file.existsSync()) return null;
    return await file.readAsBytes();
  }

  @override
  Future<void> write(String key, Uint8List pcm) async {
    final file = await _file(key);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(pcm, flush: true);
  }
}

/// The openers.
class VoiceOpeners {
  /// Creates the openers.
  new(this._synth, this._store, {math.Random? random})
    : _random = random ?? math.Random();

  final VoiceSynthesizer _synth;
  final VoiceOpenerStore _store;
  final math.Random _random;
  bool _warming = false;

  /// The key a line is kept under: its text, so a changed line is made again.
  static String keyOf(String line) {
    final hash = line.codeUnits.fold<int>(
      7,
      (h, c) => (h * 31 + c) & 0x7fffffff,
    );
    return 'opener_$hash';
  }

  /// One of the kept lines, at random, or null when none is kept yet.
  Future<Uint8List?> pick() async {
    final order = List<int>.generate(voiceOpenerLines.length, (i) => i)
      ..shuffle(_random);
    for (final i in order) {
      final pcm = await _store.read(keyOf(voiceOpenerLines[i]));
      if (pcm != null && pcm.isNotEmpty) return pcm;
    }
    return null;
  }

  /// Synthesizes the lines not kept yet, one at a time. Never throws: the
  /// first failure (no network, the voice quota spent) stops it until the
  /// next time.
  Future<void> warmUp() async {
    if (_warming) return;
    _warming = true;
    try {
      for (final line in voiceOpenerLines) {
        final key = keyOf(line);
        if (await _store.read(key) != null) continue;
        final audio = await _synth.synthesize(line);
        if (audio.pcm.isEmpty) return;
        await _store.write(key, audio.pcm);
      }
    } on Object {
      return;
    } finally {
      _warming = false;
    }
  }
}
