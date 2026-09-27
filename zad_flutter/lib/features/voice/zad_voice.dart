/// Kotlin's `ZadNaturalVoiceEngine.speakHumanLike`: زاد's human voice, from
/// `voice_synthesize` on zad-core-intelligence (Gemini TTS, Azure as the
/// fallback).
///
/// One voice for the whole app: this is a facade over
/// [VoiceOutputController], which the chat already used. The sheet, the brain
/// card and the notification center used to play through their own native
/// AudioTrack path, which could not be stopped mid-chunk (the mic then
/// recorded Zad's own voice) and never told the orb it was speaking. Now all
/// of them stop for real, pipeline the next chunk, and move the orb.
///
/// The text preparation (links, markdown, emoji, 1,200 characters, ~200-char
/// chunks, the «،» pause) is `domain/speech_text.dart`'s, as the chat's was.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/voice/application/voice_output_controller.dart';

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

/// The voice.
class ZadVoice {
  /// Creates the voice.
  new(this._ref, this._box) {
    _ref.listen(voiceOutputControllerProvider, (_, v) {
      speaking.value = v.isActive;
      level.value = v.stage == VoiceOutputStage.speaking ? v.level : 0;
    });
  }

  final Ref _ref;
  final Box<String> _box;

  /// Whether زاد is talking (or fetching the first chunk to say).
  final ValueNotifier<bool> speaking = ValueNotifier<bool>(false);

  /// Loudness of what is being said, 0..1, for the orb and the wave.
  final ValueNotifier<double> level = ValueNotifier<double>(0);

  /// The chosen persona — the one the voice sheet and the read-aloud use.
  String get persona => _box.get(kVoicePersonaKey) ?? VoicePersona.sarahWarm;

  set persona(String id) => unawaited(_box.put(kVoicePersonaKey, id));

  /// Stops whatever is being said, now.
  void stop() =>
      unawaited(_ref.read(voiceOutputControllerProvider.notifier).stop());

  /// Says [text] in [persona]'s voice (the chosen one by default).
  Future<void> speak(String text, {String? persona}) => _ref
      .read(voiceOutputControllerProvider.notifier)
      .speak(text, persona: persona ?? this.persona);
}

/// The voice.
final zadVoiceProvider = Provider<ZadVoice>(
  (ref) => ZadVoice(ref, ref.watch(localStoreProvider).device),
);
