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

  /// Three babbled syllables, a little different each time — the pet
  /// "talking" when its speech bubble opens.
  babble,

  /// Nom-nom-nom: three soft crunches, when it is fed.
  munch,

  /// Two bubbly gulps, when it drinks.
  gulp,

  /// A small falling whimper, when it is sad.
  whimper,
}

const MethodChannel _channel = MethodChannel('zad/pet_sound');
const int _sampleRate = 44100;
const double _twoPi = 2 * math.pi;
const int _shortMax = 32767;
final math.Random _rng = math.Random();

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
  PetSound.babble => _babble(v),
  PetSound.munch => _render(420, (t, p) {
    // Three bites of 100ms with 40ms between: a thump and a soft crunch.
    final bite = (p * 3).floor().clamp(0, 2);
    final q = p * 3 - bite;
    if (q > 0.72) return 0;
    final bp = q / 0.72;
    final env = math.exp(-5 * bp) * math.min(1, bp * 30);
    final thump = math.sin(_twoPi * (190 - 60 * bp) * t);
    final crunch = _noise(t) * 0.55;
    return (thump * 0.7 + crunch) * env * v * 0.7;
  }),
  PetSound.gulp => _render(300, (t, p) {
    // Two bloops rising 280 → 720Hz.
    final q = (p * 2) % 1;
    final env = math.sin(q * math.pi) * (q < 0.85 ? 1 : (1 - q) / 0.15);
    final freq = 280 + 440 * q * q;
    return math.sin(_twoPi * freq * t) * env * v * 0.75;
  }),
  PetSound.whimper => _render(520, (t, p) {
    final env = math.sin(p * math.pi);
    final freq = 720 - 260 * p + 18 * math.sin(_twoPi * 7 * t);
    final wave =
        math.sin(_twoPi * freq * t) + 0.18 * math.sin(_twoPi * freq * 2 * t);
    return wave * env * v * 0.5;
  }),
};

/// Three syllables, each with its own pitch and glide, so the pet never says
/// the same thing twice in a row.
Int16List _babble(double v) {
  final base = 760 + _rng.nextDouble() * 260;
  final syllables = <(double, double)>[
    for (var i = 0; i < 3; i++)
      (base * (0.85 + _rng.nextDouble() * 0.4), _rng.nextBool() ? 1.25 : 0.8),
  ];
  return _render(450, (t, p) {
    final i = (p * 3).floor().clamp(0, 2);
    final q = p * 3 - i;
    if (q > 0.78) return 0;
    final sp = q / 0.78;
    final (pitch, glide) = syllables[i];
    final freq = pitch * (1 + (glide - 1) * sp);
    final env = math.sin(sp * math.pi);
    // A rounder "vowel": the fundamental, its octave, and a soft wobble.
    final wave =
        math.sin(_twoPi * freq * t) +
        0.3 * math.sin(_twoPi * freq * 2 * t) +
        0.12 * math.sin(_twoPi * freq * 3 * t);
    final wobble = 0.85 + 0.15 * math.sin(_twoPi * 30 * t);
    return wave * env * wobble * v * 0.55;
  });
}

/// Repeatable noise from the sample's time, for the crunch.
double _noise(double t) {
  final x = math.sin(t * 12.9898e3) * 43758.5453;
  return (x - x.floorToDouble()) * 2 - 1;
}

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
