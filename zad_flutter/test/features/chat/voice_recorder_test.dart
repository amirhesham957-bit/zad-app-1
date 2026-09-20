// The microphone's lifecycle, which is where the old stutter lived.
//
// Every rule below exists because of one failure shape: a native capture
// session that outlives the thing that started it. Start twice without
// stopping and the second session inherits what the first never flushed —
// that is the repeated fragment. Dispose without stopping and the session
// survives the screen, so the next recording opens on top of it.
//
// These drive `DeviceVoiceRecorder` against a fake `AudioRecorder`, so the
// rules are checked rather than trusted to a device nobody has in CI.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:zad/features/chat/data/voice_recorder.dart';

/// Stands in for the plugin. Only the calls this recorder makes are real; the
/// rest throw if anything reaches for them.
class _FakeAudioRecorder implements AudioRecorder {
  bool recording = false;
  bool disposed = false;
  int starts = 0;
  int cancels = 0;
  String? path;
  bool permitted = true;

  /// What `stop` writes to disk before returning, if anything.
  Uint8List? writes = Uint8List(4096);

  final StreamController<Amplitude> amplitudes =
      StreamController<Amplitude>.broadcast();

  @override
  Future<bool> hasPermission({bool request = true}) async => permitted;

  @override
  Future<bool> isRecording() async => recording;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    starts++;
    recording = true;
    this.path = path;
  }

  @override
  Future<String?> stop() async {
    recording = false;
    final written = path;
    if (written != null && writes != null) {
      await File(written).writeAsBytes(writes!);
    }
    return written;
  }

  @override
  Future<void> cancel() async {
    cancels++;
    recording = false;
    final written = path;
    if (written != null && File(written).existsSync()) {
      await File(written).delete();
    }
  }

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) => amplitudes.stream;

  @override
  Future<void> dispose() async {
    disposed = true;
    await amplitudes.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

void main() {
  late Directory dir;
  late _FakeAudioRecorder plugin;
  late DeviceVoiceRecorder recorder;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_voice_test');
    plugin = _FakeAudioRecorder();
    recorder = DeviceVoiceRecorder(recorder: plugin, directory: dir);
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  /// Everything left in the temp directory.
  List<String> leftovers() =>
      dir.listSync().map((e) => e.path.split('/').last).toList();

  group('one session at a time', () {
    test('starting twice does not open a second capture', () async {
      // The bug in one line. A second `start` over a live session leaves the
      // first un-flushed, and its tail arrives at the front of the next clip.
      await recorder.start();
      await recorder.start();

      expect(plugin.starts, 1);
    });

    test('a new recording may start once the last one stopped', () async {
      await recorder.start();
      await Future<void>.delayed(DeviceVoiceRecorder.minimumClip);
      await recorder.stop();

      await recorder.start();

      expect(plugin.starts, 2);
    });
  });

  group('clips that are not speech', () {
    test('a press shorter than the minimum is discarded', () async {
      await recorder.start();
      // Released immediately — the tap this rule exists to absorb.
      await expectLater(
        recorder.stop(),
        throwsA(
          isA<VoiceClipDiscarded>().having(
            (e) => e.reason,
            'reason',
            VoiceDiscard.tooShort,
          ),
        ),
      );
    });

    test(
      'an empty capture is discarded even when it ran long enough',
      () async {
        // A muted microphone, or a session that never really opened: the
        // encoder still writes a container, so duration alone would let it
        // through and Whisper would be paid to hear nothing.
        plugin.writes = Uint8List(16);
        await recorder.start();
        await Future<void>.delayed(DeviceVoiceRecorder.minimumClip);

        await expectLater(
          recorder.stop(),
          throwsA(
            isA<VoiceClipDiscarded>().having(
              (e) => e.reason,
              'reason',
              VoiceDiscard.empty,
            ),
          ),
        );
      },
    );

    test('a real clip comes back with its bytes and its length', () async {
      await recorder.start();
      await Future<void>.delayed(DeviceVoiceRecorder.minimumClip);

      final clip = await recorder.stop();

      expect(clip.bytes, hasLength(4096));
      expect(
        clip.duration,
        greaterThanOrEqualTo(DeviceVoiceRecorder.minimumClip),
      );
      expect(clip.mimeType, 'audio/m4a');
    });
  });

  group('nothing is left on disk', () {
    test('after a clip is taken', () async {
      await recorder.start();
      await Future<void>.delayed(DeviceVoiceRecorder.minimumClip);
      await recorder.stop();

      expect(leftovers(), isEmpty);
    });

    test('after a clip is discarded for being too short', () async {
      await recorder.start();
      try {
        await recorder.stop();
      } on VoiceClipDiscarded {
        // The point of the test is what is left behind, not the throw.
      }

      // A recording of somebody's kitchen that nobody asked to keep.
      expect(leftovers(), isEmpty);
    });

    test('after a cancel', () async {
      await recorder.start();
      await recorder.cancel();

      expect(plugin.cancels, 1);
      expect(plugin.recording, isFalse);
      expect(leftovers(), isEmpty);
    });
  });

  group('teardown', () {
    test('disposing a live recorder stops it first', () async {
      await recorder.start();
      await recorder.dispose();

      // Released *after* being stopped. The other order is what leaves the
      // session running behind a screen that has gone.
      expect(plugin.recording, isFalse);
      expect(plugin.cancels, 1);
      expect(plugin.disposed, isTrue);
      expect(leftovers(), isEmpty);
    });

    test('disposing twice is not an error', () async {
      await recorder.dispose();
      await recorder.dispose();

      expect(plugin.disposed, isTrue);
    });

    test(
      'starting after dispose is refused rather than silently ignored',
      () async {
        await recorder.dispose();

        await expectLater(recorder.start(), throwsStateError);
      },
    );
  });

  group('the waveform', () {
    test(
      'maps decibels onto 0..1 so silence is flat and loud is full',
      () async {
        final levels = <double>[];
        final sub = recorder.amplitude().listen(levels.add);

        plugin.amplitudes
          ..add(Amplitude(current: -60, max: 0))
          ..add(Amplitude(current: -30, max: 0))
          ..add(Amplitude(current: 0, max: 0))
          // Below the floor, which a quiet room produces.
          ..add(Amplitude(current: -90, max: 0));
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(levels[0], 0);
        expect(levels[1], closeTo(0.5, 0.01));
        expect(levels[2], 1);
        expect(levels[3], 0, reason: 'clamped, not negative');
      },
    );
  });
}
