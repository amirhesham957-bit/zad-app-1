/// Kotlin's `ZadCutePetSoundFx`: the companion's little sounds, synthesised
/// on the spot — no sound files. Same six sounds, same formulas, same 44.1kHz
/// mono 16-bit PCM; the samples are made here and played by the host
/// activity's `AudioTrack`, as Kotlin plays them.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The sounds.
enum PetSound {
  /// A warm purr, while being dragged.
  purr,

  /// A playful meow-chirp.
  meowChirp,

  /// A quick happy chirp, on a tap.
  happyChirp,

  /// A rising celebration trill, on a double tap.
  celebrationTrill,

  /// A light squeak.
  cuteSqueak,

  /// A sleepy sigh.
  sleepySigh,
}

const MethodChannel _channel = MethodChannel('zad/pet_sound');
const int _sampleRate = 44100;
const double _twoPi = 2 * math.pi;
const int _shortMax = 32767;

/// Plays [sound] at [volume] (0..1). Fire and forget; a device that cannot
/// play it simply stays quiet, as Kotlin's does.
void playPetSound(PetSound sound, {double volume = 0.45}) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  final pcm = _generate(sound, volume.clamp(0, 1));
  unawaited(
    _channel
        .invokeMethod<void>('play', <String, Object>{
          'pcm': pcm.buffer.asUint8List(),
          'sampleRate': _sampleRate,
        })
        .catchError((Object _) {}),
  );
}

Int16List _generate(PetSound sound, double v) => switch (sound) {
  PetSound.purr => _render(420, (t, p) {
    final env = math.sin(p * math.pi).clamp(0.0, 1.0);
    final mod = 0.5 + 0.5 * math.sin(_twoPi * 24 * t);
    final wave = math.sin(_twoPi * 78 * t) + 0.35 * math.sin(_twoPi * 156 * t);
    return wave * mod * env * v * 0.7;
  }),
  PetSound.meowChirp => _render(260, (t, p) {
    final env = p < 0.2 ? p / 0.2 : math.exp(-4.2 * (p - 0.2));
    final freq = 580 + 340 * math.sin(p * math.pi);
    final wave =
        math.sin(_twoPi * freq * t) +
        0.25 * math.sin(_twoPi * (freq * 2.02) * t);
    return wave * env * v * 0.75;
  }),
  PetSound.happyChirp => _render(180, (t, p) {
    final env = math.sin(p * math.pi);
    final freq = 880 + 400 * p;
    final wave =
        math.sin(_twoPi * freq * t) + 0.2 * math.sin(_twoPi * freq * 1.5 * t);
    return wave * env * v * 0.7;
  }),
  PetSound.celebrationTrill => _render(380, (t, p) {
    const notes = <double>[880, 1174.66, 1318.51, 1760];
    final index = (p * notes.length).toInt().clamp(0, notes.length - 1);
    final freq = notes[index];
    final noteP = p * notes.length - index;
    final env = math.sin(noteP * math.pi).clamp(0.0, 1.0) * (1 - p * 0.2);
    final wave =
        math.sin(_twoPi * freq * t) + 0.15 * math.sin(_twoPi * freq * 2 * t);
    return wave * env * v * 0.8;
  }),
  PetSound.cuteSqueak => _render(120, (t, p) {
    final env = (1 - p) * (1 - p);
    final freq = 1200 + 600 * (1 - p);
    return math.sin(_twoPi * freq * t) * env * v * 0.65;
  }),
  PetSound.sleepySigh => _render(500, (t, p) {
    final env = math.sin(p * math.pi);
    final freq = 440 - 180 * p;
    final wave =
        math.sin(_twoPi * freq * t) + 0.1 * math.sin(_twoPi * freq * 3 * t);
    return wave * env * v * 0.5;
  }),
};

/// Kotlin's loop: `SAMPLE_RATE * durationMs / 1000` samples, each the
/// formula times `Short.MAX_VALUE`, truncated and clamped to a short.
Int16List _render(int durationMs, double Function(double t, double p) f) {
  final total = _sampleRate * durationMs ~/ 1000;
  final out = Int16List(total);
  for (var i = 0; i < total; i++) {
    final s = (f(i / _sampleRate, i / total) * _shortMax).toInt();
    out[i] = s.clamp(-32768, _shortMax);
  }
  return out;
}
