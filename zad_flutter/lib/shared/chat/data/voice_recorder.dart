/// The microphone, with a lifecycle that closes.
///
/// Every rule here exists because of the same class of bug: a recorder that
/// is started again without being stopped, or stopped without being disposed,
/// leaves a native capture session running. What the customer then hears is
/// the old buffer — the stutter and the repeated fragment — because the second
/// session picks up what the first one never flushed.
///
/// So: one session at a time, enforced rather than assumed; every exit path
/// goes through the same teardown; and the temporary file is deleted whether
/// the clip was used or thrown away.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// A finished recording.
class VoiceClip {
  /// Creates a clip.
  const new({
    required this.bytes,
    required this.duration,
    this.mimeType = 'audio/m4a',
  });

  /// The encoded audio.
  final Uint8List bytes;

  /// How long it ran.
  final Duration duration;

  /// What it is, for the transcriber's form field.
  final String mimeType;
}

/// Why a recording produced nothing.
enum VoiceDiscard {
  /// Shorter than `DeviceVoiceRecorder.minimumClip`.
  tooShort,

  /// The encoder wrote a header and no audio — a muted microphone, a session
  /// that never actually opened.
  empty,
}

/// Thrown when a clip is not worth sending.
class VoiceClipDiscarded implements Exception {
  /// Creates a discard.
  const new(this.reason);

  /// Which rule it broke.
  final VoiceDiscard reason;

  @override
  String toString() => 'VoiceClipDiscarded(${reason.name})';
}

/// Records one clip at a time.
abstract interface class VoiceRecorder {
  /// Whether the microphone may be used, asking if it has not been asked.
  Future<bool> hasPermission();

  /// Starts capturing. Does nothing if already capturing.
  Future<void> start();

  /// Stops and returns the clip.
  ///
  /// Throws [VoiceClipDiscarded] for a clip too short or too small to be
  /// speech, which is the rule that stops a tap-and-release from firing a
  /// transcription request per tap.
  Future<VoiceClip> stop();

  /// Stops and throws the audio away.
  Future<void> cancel();

  /// Loudness while recording, 0..1, for the waveform.
  Stream<double> amplitude();

  /// Releases the native session. Safe to call twice.
  Future<void> dispose();
}

/// The real microphone.
class DeviceVoiceRecorder implements VoiceRecorder {
  /// Creates a recorder.
  new({AudioRecorder? recorder, Directory? directory})
    : _recorder = recorder ?? AudioRecorder(),
      _directory = directory;

  final AudioRecorder _recorder;
  final Directory? _directory;

  String? _path;
  DateTime? _startedAt;
  bool _disposed = false;

  /// The shortest clip worth sending.
  ///
  /// Below this there is no speech in it — it is the press and release of a
  /// button. Sending it costs a round trip, a Whisper call, and comes back
  /// empty, which is what made repeated tapping feel like the app was
  /// stuttering rather than ignoring an empty clip.
  static const Duration minimumClip = Duration(milliseconds: 500);

  /// The smallest file that can hold speech.
  ///
  /// An AAC container with no audio in it is still around a kilobyte, so
  /// duration alone does not catch a microphone that never opened.
  static const int minimumBytes = 1024;

  /// How often the waveform is sampled.
  static const Duration amplitudeInterval = Duration(milliseconds: 120);

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start() async {
    if (_disposed) throw StateError('recorder was disposed');
    // The guard, not an optimisation. `start` on a running session is what
    // leaves the first one un-flushed, and the second recording then carries
    // the tail of the first.
    if (await _recorder.isRecording()) return;

    final dir = _directory ?? await getTemporaryDirectory();
    final path =
        '${dir.path}/zad_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      // The encoder and channel count are left at their defaults — AAC-LC,
      // mono — which is what the `.m4a` extension above promises and what the
      // server's `transcribeAudio` assumes when it names the upload. Setting
      // them explicitly is what the analyzer objects to; changing them is what
      // would break the pair.
      const RecordConfig(
        // Whisper resamples to 16 kHz anyway, so anything above it is bytes on
        // the wire for nothing.
        sampleRate: 16000,
        echoCancel: true,
        noiseSuppress: true,
      ),
      path: path,
    );

    _path = path;
    _startedAt = DateTime.now();
  }

  @override
  Future<VoiceClip> stop() async {
    final startedAt = _startedAt;
    final path = await _recorder.stop() ?? _path;
    _startedAt = null;
    _path = null;

    if (path == null || startedAt == null) {
      throw const VoiceClipDiscarded(VoiceDiscard.empty);
    }

    final file = File(path);
    final duration = DateTime.now().difference(startedAt);

    try {
      if (duration < minimumClip) {
        throw const VoiceClipDiscarded(VoiceDiscard.tooShort);
      }
      if (!file.existsSync()) {
        throw const VoiceClipDiscarded(VoiceDiscard.empty);
      }

      final bytes = await file.readAsBytes();
      if (bytes.length < minimumBytes) {
        throw const VoiceClipDiscarded(VoiceDiscard.empty);
      }

      return VoiceClip(bytes: bytes, duration: duration);
    } finally {
      // Deleted on every path, including the two throws above. A discarded
      // clip that stays on disk is a recording of the customer's kitchen that
      // nobody asked to keep.
      await _delete(file);
    }
  }

  @override
  Future<void> cancel() async {
    _startedAt = null;
    final path = _path;
    _path = null;
    // `cancel` on the plugin stops and deletes; the explicit delete below
    // covers the case where it stopped without removing the file.
    await _recorder.cancel();
    if (path != null) await _delete(File(path));
  }

  @override
  Stream<double> amplitude() => _recorder
      .onAmplitudeChanged(amplitudeInterval)
      // dBFS, which runs from about -60 (silence) to 0 (clipping), mapped to
      // 0..1 so the waveform does not have to know about decibels.
      .map((a) => ((a.current + 60) / 60).clamp(0.0, 1.0));

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    // Stop before releasing. Disposing a running recorder is the other way to
    // leave a session behind.
    try {
      if (await _recorder.isRecording()) await _recorder.cancel();
    } on Object {
      // Already gone. Releasing is still the right next step.
    }
    final path = _path;
    _path = null;
    if (path != null) await _delete(File(path));
    await _recorder.dispose();
  }

  static Future<void> _delete(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } on Object {
      // A temp file that will not delete is the operating system's problem,
      // not a reason to fail a recording the customer just made.
    }
  }
}
