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
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
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
    this.level = 0,
  });

  /// Where the voice is.
  final VoiceOutputStage stage;

  /// The chat message being spoken, when it is one.
  final String? messageId;

  /// The last request could not be spoken.
  final bool failed;

  /// Who spoke the last chunk: `gemini` or `azure`.
  final String? provider;

  /// Loudness of the chunk playing, 0..1, for the orb and the wave bars.
  final double level;

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

    // Two chunks ahead, not one: a chunk takes longer to synthesize than to
    // play, so with one in flight every chunk after the first left a gap.
    final pending = <int, Future<SpokenAudio>>{};
    var requested = 0;
    void fetchUpTo(int last) {
      for (; requested <= last && requested < chunks.length; requested++) {
        pending[requested] = synth.synthesize(chunks[requested]);
      }
    }

    void dropPending() {
      for (final f in pending.values) {
        f.ignore();
      }
    }

    fetchUpTo(1);
    try {
      for (var i = 0; i < chunks.length; i++) {
        final audio = await pending.remove(i)!;
        fetchUpTo(i + 2);
        if (!ref.mounted || generation != _generation) {
          dropPending();
          return;
        }
        state = VoiceOutputView(
          stage: VoiceOutputStage.speaking,
          messageId: messageId,
          provider: audio.provider,
          level: pcmLoudness(audio.pcm),
        );
        // An interrupted play() returns early; the check at the top of the
        // next pass is what stops this run.
        await player.play(pcmToWav(audio.pcm));
      }
      if (ref.mounted && generation == _generation) {
        state = VoiceOutputView(provider: state.provider);
      }
    } on Object catch (e) {
      dropPending();
      debugPrint('voice_synthesize failed: $e');
      if (ref.mounted && generation == _generation) {
        state = const VoiceOutputView(failed: true);
      }
    }
  }

  /// Starts speaking a reply that is still arriving: feed it with
  /// [StreamedSpeech.add] as the text streams in and end it with
  /// [StreamedSpeech.finish]. The first chunk is asked for as soon as a
  /// sentence ends past [firstStreamedChunk] characters, so Zad talks while
  /// the brain is still writing instead of after it has finished.
  StreamedSpeech speakStreaming({String? messageId}) {
    final chunks = StreamController<String>();
    unawaited(_speakArriving(chunks.stream, messageId: messageId));
    return StreamedSpeech._(chunks);
  }

  Future<void> _speakArriving(
    Stream<String> chunks, {
    String? messageId,
  }) async {
    final generation = ++_generation;
    final synth = ref.read(voiceSynthesizerProvider);
    final player = ref.read(voicePlayerProvider);
    final arriving = StreamIterator<String>(chunks);
    await player.stop();
    if (!ref.mounted || generation != _generation) {
      await arriving.cancel();
      return;
    }
    state = VoiceOutputView(
      stage: VoiceOutputStage.preparing,
      messageId: messageId,
    );

    // A record, not a nested future: `async` would flatten Future<Future<…>>
    // and wait for the audio before handing back the chunk.
    Future<({Future<SpokenAudio> audio})?> ask() async {
      if (!await arriving.moveNext()) return null;
      final audio = synth.synthesize(arriving.current)..ignore();
      return (audio: audio);
    }

    // One chunk ahead, as [speak] does: the next is asked for while the
    // current one plays, and never more than that at once.
    var next = ask();
    try {
      while (true) {
        final pending = await next;
        if (pending == null) break;
        final audio = await pending.audio;
        if (!ref.mounted || generation != _generation) return;
        next = ask();
        state = VoiceOutputView(
          stage: VoiceOutputStage.speaking,
          messageId: messageId,
          provider: audio.provider,
          level: pcmLoudness(audio.pcm),
        );
        await player.play(pcmToWav(audio.pcm));
        if (!ref.mounted || generation != _generation) return;
      }
      if (ref.mounted && generation == _generation) {
        state = VoiceOutputView(provider: state.provider);
      }
    } on Object catch (e) {
      debugPrint('voice_synthesize failed: $e');
      if (ref.mounted && generation == _generation) {
        state = const VoiceOutputView(failed: true);
      }
    } finally {
      next.ignore();
      await arriving.cancel();
    }
  }

  /// Stops speaking now.
  Future<void> stop() async {
    _generation++;
    if (state.isActive) state = const VoiceOutputView();
    await ref.read(voicePlayerProvider).stop();
  }
}

/// A reply being spoken while it arrives. See
/// [VoiceOutputController.speakStreaming].
class StreamedSpeech {
  new _(this._chunks);

  final StreamController<String> _chunks;
  final SpeechStreamSplitter _splitter = SpeechStreamSplitter();
  var _closed = false;
  var _heard = false;

  /// Whether any text has been added.
  bool get heardAnything => _heard;

  /// More of the reply.
  void add(String delta) {
    if (_closed || delta.isEmpty) return;
    _heard = true;
    _splitter.add(delta).forEach(_chunks.add);
  }

  /// The reply is complete: whatever is left is spoken.
  void finish() {
    if (_closed) return;
    _splitter.finish().forEach(_chunks.add);
    _close();
  }

  /// The reply failed: nothing more is queued. What is already queued plays.
  void cancel() => _close();

  void _close() {
    _closed = true;
    unawaited(_chunks.close());
  }
}

/// RMS of 16-bit little-endian PCM, scaled to 0..1 (every fourth sample).
double pcmLoudness(Uint8List pcm) {
  final n = pcm.length ~/ 2;
  if (n == 0) return 0;
  final data = ByteData.sublistView(pcm);
  var sum = 0.0;
  var count = 0;
  for (var i = 0; i < n; i += 4) {
    final v = data.getInt16(i * 2, Endian.little) / 32768;
    sum += v * v;
    count++;
  }
  return (math.sqrt(sum / count) * 3).clamp(0, 1).toDouble();
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
