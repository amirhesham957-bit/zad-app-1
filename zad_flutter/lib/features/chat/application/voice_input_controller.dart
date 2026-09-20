/// Holding the microphone button down.
///
/// The transcript lands in the composer rather than being sent. Whisper on
/// dialect Arabic is good and not certain, and the difference between "سجل
/// خمسين" and "سجل خمسمية" is money — so the customer reads it before it
/// becomes a turn. It also means the voice path has no separate way of doing
/// anything: the words go through the same `send` a typed message does.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/features/chat/data/transcriber.dart';
import 'package:zad/features/chat/data/voice_recorder.dart';

/// Where the microphone is.
enum VoiceStage {
  /// Nothing is happening.
  idle,

  /// Capturing.
  recording,

  /// The clip is with Whisper.
  transcribing,

  /// The press was too brief, or held nothing. Not an error — a nudge.
  tooShort,

  /// The microphone was refused.
  denied,

  /// The transcription call failed.
  failed,
}

/// What the composer's microphone draws.
class VoiceInputView {
  /// Creates a view.
  const new({
    this.stage = VoiceStage.idle,
    this.amplitude = 0,
    this.transcript,
  });

  /// Where things are.
  final VoiceStage stage;

  /// Loudness, 0..1, for the waveform.
  final double amplitude;

  /// The words, once they arrive. Read once by the screen and cleared.
  final String? transcript;

  /// Whether the microphone is live.
  bool get isRecording => stage == VoiceStage.recording;

  /// Whether anything is in flight.
  bool get isBusy =>
      stage == VoiceStage.recording || stage == VoiceStage.transcribing;

  /// A copy with the given fields replaced.
  VoiceInputView copyWith({
    VoiceStage? stage,
    double? amplitude,
    String? transcript,
    bool clearTranscript = false,
  }) => VoiceInputView(
    stage: stage ?? this.stage,
    amplitude: amplitude ?? this.amplitude,
    transcript: clearTranscript ? null : (transcript ?? this.transcript),
  );
}

/// Drives one recording.
class VoiceInputController extends Notifier<VoiceInputView> {
  StreamSubscription<double>? _amplitude;

  @override
  VoiceInputView build() {
    // Held now rather than read inside the callback: a disposal hook may not
    // touch `ref`, and reaching for the provider there throws instead of
    // releasing the microphone — which is the one moment it must not fail.
    final recorder = ref.read(voiceRecorderProvider);

    // The screen can be left mid-recording — a back gesture, a tab switch, a
    // sign-out. Without this the native session outlives the screen and the
    // next recording starts on top of it.
    ref.onDispose(() {
      unawaited(_amplitude?.cancel());
      unawaited(recorder.dispose());
    });
    return const VoiceInputView();
  }

  /// Starts capturing.
  Future<void> start() async {
    if (!ref.mounted || state.isBusy) return;

    final recorder = ref.read(voiceRecorderProvider);
    try {
      if (!await recorder.hasPermission()) {
        if (ref.mounted) state = const VoiceInputView(stage: VoiceStage.denied);
        return;
      }

      await recorder.start();
      if (!ref.mounted) {
        // Disposed while the permission dialog was up. Stop what was just
        // started rather than leaving it running behind a dead screen.
        await recorder.cancel();
        return;
      }

      state = const VoiceInputView(stage: VoiceStage.recording);
      await _amplitude?.cancel();
      _amplitude = recorder.amplitude().listen((level) {
        if (ref.mounted && state.isRecording) {
          state = state.copyWith(amplitude: level);
        }
      });
    } on Object {
      if (!ref.mounted) return;
      await _stopAmplitude();
      state = const VoiceInputView(stage: VoiceStage.failed);
    }
  }

  /// Stops, transcribes, and leaves the words in [VoiceInputView.transcript].
  Future<void> stopAndTranscribe() async {
    if (!ref.mounted || !state.isRecording) return;
    await _stopAmplitude();
    state = const VoiceInputView(stage: VoiceStage.transcribing);

    final recorder = ref.read(voiceRecorderProvider);
    try {
      final clip = await recorder.stop();
      final heard = await ref.read(transcriberProvider).transcribe(clip);
      if (!ref.mounted) return;

      // Trimmed here as well as in the transcriber. Whether a whitespace-only
      // answer counts as speech is this controller's decision, not the
      // transport's, and putting a blank string in the composer would leave
      // the customer looking at a send button that does nothing.
      final transcript = heard?.trim();
      state = transcript == null || transcript.isEmpty
          // Whisper heard nothing. Same nudge as a clip that was too short,
          // because the fix is the same: say it again, closer.
          ? const VoiceInputView(stage: VoiceStage.tooShort)
          : VoiceInputView(transcript: transcript);
    } on VoiceClipDiscarded {
      if (ref.mounted) state = const VoiceInputView(stage: VoiceStage.tooShort);
    } on Object {
      if (ref.mounted) state = const VoiceInputView(stage: VoiceStage.failed);
    }
  }

  /// Throws the recording away.
  Future<void> cancel() async {
    await _stopAmplitude();
    await ref.read(voiceRecorderProvider).cancel();
    if (ref.mounted) state = const VoiceInputView();
  }

  /// Marks the transcript as taken, so it is not inserted twice.
  void transcriptTaken() {
    if (ref.mounted) state = const VoiceInputView();
  }

  Future<void> _stopAmplitude() async {
    await _amplitude?.cancel();
    _amplitude = null;
  }
}

/// The microphone.
final voiceRecorderProvider = Provider<VoiceRecorder>(
  (ref) => DeviceVoiceRecorder(),
);

/// Whisper, on the server.
final transcriberProvider = Provider<Transcriber>(
  (ref) => SupabaseTranscriber(ref.watch(supabaseClientProvider)),
);

/// The composer's microphone.
final voiceInputControllerProvider =
    NotifierProvider<VoiceInputController, VoiceInputView>(
      VoiceInputController.new,
    );
