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
import 'package:zad/shared/brain/data/memory_repository.dart';
import 'package:zad/shared/chat/application/voice_input_controller.dart';
import 'package:zad/shared/voice/data/voice_openers.dart';
import 'package:zad/shared/voice/data/voice_player.dart';
import 'package:zad/shared/voice/data/voice_synthesizer.dart';
import 'package:zad/shared/voice/domain/speech_text.dart';

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
        pending[requested] = synth.synthesize(
          chunks[requested],
          feelingFrom: chunks.first,
        );
      }
    }

    void dropPending() {
      for (final f in pending.values) {
        f.ignore();
      }
    }

    fetchUpTo(1);
    // The next chunk, loaded into the idle player while this one plays, so
    // one sentence runs into the next without a gap (PreparingVoicePlayer).
    ({int index, Uint8List wav})? prepared;
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
        final wav = prepared?.index == i
            ? prepared!.wav
            : pcmToWav(smoothPcmEdges(audio.pcm));
        prepared = null;
        // An interrupted play() returns early; the check at the top of the
        // next pass is what stops this run.
        final playing = player.play(wav);
        final upcoming = pending[i + 1];
        if (player is PreparingVoicePlayer && upcoming != null) {
          final next = i + 1;
          unawaited(
            upcoming.then((a) async {
              if (!ref.mounted || generation != _generation) return;
              final w = pcmToWav(smoothPcmEdges(a.pcm));
              prepared = (index: next, wav: w);
              await player.prepare(w);
            }, onError: (Object _) {}),
          );
        }
        await playing;
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
  ///
  /// With [opener], a short line زاد has said before and the device kept
  /// («لحظة واحدة…») plays at once, while the answer is still being thought
  /// and synthesized — a spoken question used to meet ten seconds of silence.
  StreamedSpeech speakStreaming({String? messageId, bool opener = false}) {
    final chunks = StreamController<String>();
    unawaited(
      _speakArriving(chunks.stream, messageId: messageId, opener: opener),
    );
    return StreamedSpeech._(chunks);
  }

  /// How many chunks are synthesized at once. Each is its own request on the
  /// server's key pool, and every one of them used to wait for the audio of
  /// the one before it (function logs, 2026-09-30: the second sentence's
  /// request started only after the first's 6.5 s had passed).
  static const int _inFlight = 3;

  Future<void> _speakArriving(
    Stream<String> chunks, {
    String? messageId,
    bool opener = false,
  }) async {
    final generation = ++_generation;
    final synth = ref.read(voiceSynthesizerProvider);
    final player = ref.read(voicePlayerProvider);
    bool current() => ref.mounted && generation == _generation;
    await player.stop();
    if (!current()) {
      await chunks.listen(null).cancel();
      return;
    }
    state = VoiceOutputView(
      stage: VoiceOutputStage.preparing,
      messageId: messageId,
    );

    // Every chunk is asked for the moment the reply releases it, a few at
    // once, and played in order.
    final queue = _AudioQueue();
    final slots = _Slots(_inFlight);
    String? first;
    unawaited(() async {
      try {
        await for (final text in chunks) {
          first ??= text;
          if (!current()) break;
          await slots.acquire();
          if (!current()) {
            slots.release();
            break;
          }
          queue.add(
            synth
                .synthesize(text, feelingFrom: first)
                .whenComplete(slots.release)
              ..ignore(),
          );
        }
      } on Object catch (_) {
        // A reply that failed mid-way: what is queued still plays.
      } finally {
        queue.close();
      }
    }());

    Future<void>? openerPlaying;
    if (opener) {
      final clip = await _openerClip();
      if (clip != null && current()) {
        openerPlaying = player.play(pcmToWav(smoothPcmEdges(clip)));
      }
    }

    // As in [speak]: the next chunk is loaded while this one plays.
    ({int index, Uint8List wav})? prepared;
    try {
      for (var i = 0; ; i++) {
        final pending = await queue.at(i);
        if (pending == null) break;
        final audio = await pending.audio;
        if (!current()) return;
        if (openerPlaying != null) {
          await openerPlaying;
          openerPlaying = null;
          if (!current()) return;
        }
        state = VoiceOutputView(
          stage: VoiceOutputStage.speaking,
          messageId: messageId,
          provider: audio.provider,
          level: pcmLoudness(audio.pcm),
        );
        final wav = prepared?.index == i
            ? prepared!.wav
            : pcmToWav(smoothPcmEdges(audio.pcm));
        prepared = null;
        final playing = player.play(wav);
        if (player is PreparingVoicePlayer) {
          final next = i + 1;
          unawaited(
            queue
                .at(next)
                .then((p) async {
                  if (p == null) return;
                  final a = await p.audio;
                  if (!current()) return;
                  final w = pcmToWav(smoothPcmEdges(a.pcm));
                  prepared = (index: next, wav: w);
                  await player.prepare(w);
                })
                .catchError((Object _) {}),
          );
        }
        await playing;
        if (!current()) return;
      }
      await openerPlaying;
      if (current()) state = VoiceOutputView(provider: state.provider);
    } on Object catch (e) {
      debugPrint('voice_synthesize failed: $e');
      if (current()) state = const VoiceOutputView(failed: true);
    } finally {
      queue.dropAll();
    }
  }

  /// A kept opener, or null when none is ready — never a wait on the network.
  Future<Uint8List?> _openerClip() async {
    try {
      return await ref
          .read(voiceOpenersProvider)
          .pick()
          .timeout(const Duration(milliseconds: 400));
    } on Object {
      return null;
    }
  }

  /// Stops speaking now.
  Future<void> stop() async {
    _generation++;
    if (state.isActive) state = const VoiceOutputView();
    await ref.read(voicePlayerProvider).stop();
  }
}

/// Chunks' audio in reply order, as each request goes out.
class _AudioQueue {
  final List<Future<SpokenAudio>> _items = <Future<SpokenAudio>>[];
  var _closed = false;
  Completer<void>? _grew;

  void add(Future<SpokenAudio> audio) {
    _items.add(audio);
    _wake();
  }

  void close() {
    _closed = true;
    _wake();
  }

  void _wake() {
    final grew = _grew;
    _grew = null;
    if (grew != null && !grew.isCompleted) grew.complete();
  }

  /// The [i]th chunk's audio once it has been asked for, or null when the
  /// reply ended before it. A record, not a nested future: `async` would
  /// flatten a nested future and wait for the audio itself.
  Future<({Future<SpokenAudio> audio})?> at(int i) async {
    while (i >= _items.length) {
      if (_closed) return null;
      await (_grew ??= Completer<void>()).future;
    }
    return (audio: _items[i]);
  }

  /// Nothing waiting on a chunk that will not play reports its failure.
  void dropAll() {
    for (final f in _items) {
      f.ignore();
    }
  }
}

/// A counting semaphore.
class _Slots {
  new(this._free);

  int _free;
  final List<Completer<void>> _waiting = <Completer<void>>[];

  Future<void> acquire() {
    if (_free > 0) {
      _free--;
      return Future<void>.value();
    }
    final c = Completer<void>();
    _waiting.add(c);
    return c.future;
  }

  void release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeAt(0).complete();
    } else {
      _free++;
    }
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

/// The short lines said before an answer is ready, kept on the device.
final voiceOpenersProvider = Provider<VoiceOpeners>(
  (ref) => VoiceOpeners(
    ref.watch(voiceSynthesizerProvider),
    const FileVoiceOpenerStore(),
    // The voice chosen in «ملفي», read when a line is picked or made — a
    // change shows on the next spoken turn.
    voice: () =>
        ref.read(memoryRepositoryProvider).cached().profile?.zadVoice ??
        'female',
  ),
);

/// The device's player.
final voicePlayerProvider = Provider<VoicePlayer>((ref) {
  final player = AudioplayersVoicePlayer();
  ref.onDispose(() => unawaited(player.dispose()));
  return player;
});
