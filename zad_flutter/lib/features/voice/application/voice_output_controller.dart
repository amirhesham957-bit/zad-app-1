/// Zad speaking: a reply, chunk by chunk, with the next chunk fetched while
/// the current one plays — Kotlin's
/// `ZadNaturalVoiceEngine.speakChunksPipelined`.
///
/// A new request or the microphone interrupts: every run carries a
/// generation, and a run that is no longer the latest stops at its next step
/// (Kotlin's generation counter). No robotic fallback — if the server cannot
/// speak, Zad stays silent and says so, as Kotlin does.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/chat/application/voice_input_controller.dart';
import 'package:zad/features/voice/data/voice_player.dart';
import 'package:zad/features/voice/data/voice_synthesizer.dart';
import 'package:zad/features/voice/domain/speech_text.dart';

/// Where the voice is.
enum VoiceOutputStage {
  /// Silent.
  idle,

  /// The first chunk is being synthesized.
  preparing,

  /// Audio is playing.
  speaking,
}

/// What the orb and the speaker buttons draw.
@immutable
class VoiceOutputView {
  /// Creates a view.
  const new({
    this.stage = VoiceOutputStage.idle,
    this.messageId,
    this.failed = false,
    this.provider,
  });

  /// Where the voice is.
  final VoiceOutputStage stage;

  /// The chat message being spoken, when it is one.
  final String? messageId;

  /// The last request could not be spoken.
  final bool failed;

  /// Who spoke the last chunk: `gemini` or `azure`.
  final String? provider;

  /// Whether anything is under way.
  bool get isActive => stage != VoiceOutputStage.idle;
}

/// The voice.
class VoiceOutputController extends Notifier<VoiceOutputView> {
  var _generation = 0;

  @override
  VoiceOutputView build() {
    // The customer talking wins over Zad talking.
    ref.listen(voiceInputControllerProvider.select((v) => v.stage), (_, s) {
      if (s == VoiceStage.recording) unawaited(stop());
    });
    return const VoiceOutputView();
  }

  /// Speaks [text]; [messageId] marks which chat bubble it belongs to.
  /// Completes when it has finished, been interrupted, or failed.
  Future<void> speak(String text, {String? messageId}) async {
    final chunks = speechChunks(text);
    if (chunks.isEmpty) return;
    final generation = ++_generation;
    final synth = ref.read(voiceSynthesizerProvider);
    final player = ref.read(voicePlayerProvider);
    await player.stop();
    if (!ref.mounted || generation != _generation) return;
    state = VoiceOutputView(
      stage: VoiceOutputStage.preparing,
      messageId: messageId,
    );

    Future<SpokenAudio>? next = synth.synthesize(chunks.first);
    try {
      for (var i = 0; i < chunks.length; i++) {
        final audio = await next!;
        next = i + 1 < chunks.length ? synth.synthesize(chunks[i + 1]) : null;
        if (!ref.mounted || generation != _generation) {
          next?.ignore();
          return;
        }
        state = VoiceOutputView(
          stage: VoiceOutputStage.speaking,
          messageId: messageId,
          provider: audio.provider,
        );
        // An interrupted play() returns early; the check at the top of the
        // next pass is what stops this run.
        await player.play(pcmToWav(audio.pcm));
      }
      if (ref.mounted && generation == _generation) {
        state = VoiceOutputView(provider: state.provider);
      }
    } on Object catch (e) {
      next?.ignore();
      debugPrint('voice_synthesize failed: $e');
      if (ref.mounted && generation == _generation) {
        state = const VoiceOutputView(failed: true);
      }
    }
  }

  /// Stops speaking now.
  Future<void> stop() async {
    _generation++;
    if (state.isActive) state = const VoiceOutputView();
    await ref.read(voicePlayerProvider).stop();
  }
}

/// The voice.
final voiceOutputControllerProvider =
    NotifierProvider<VoiceOutputController, VoiceOutputView>(
      VoiceOutputController.new,
    );

/// The server's text-to-speech.
final voiceSynthesizerProvider = Provider<VoiceSynthesizer>(
  (ref) => SupabaseVoiceSynthesizer(ref.watch(supabaseClientProvider)),
);

/// The device's player.
final voicePlayerProvider = Provider<VoicePlayer>((ref) {
  final player = AudioplayersVoicePlayer();
  ref.onDispose(() => unawaited(player.dispose()));
  return player;
});
