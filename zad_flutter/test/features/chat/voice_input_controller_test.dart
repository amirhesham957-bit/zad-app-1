// The microphone button's state machine.
//
// The habit this is built to break is pressing again because nothing looked
// different. So the states have to be distinct and they have to be reached —
// a clip too short must land on a nudge rather than on silence, a refused
// permission must say so, and the transcript must arrive in the composer
// rather than being sent on the customer's behalf.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/chat/application/voice_input_controller.dart';
import 'package:zad/features/chat/data/transcriber.dart';
import 'package:zad/features/chat/data/voice_recorder.dart';

class _FakeRecorder implements VoiceRecorder {
  bool permitted = true;
  bool started = false;
  bool disposed = false;
  int cancels = 0;
  int starts = 0;

  VoiceClip clip = VoiceClip(
    bytes: Uint8List(4096),
    duration: const Duration(seconds: 2),
  );
  Exception? stopThrows;

  final StreamController<double> levels = StreamController<double>.broadcast();

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<void> start() async {
    starts++;
    started = true;
  }

  @override
  Future<VoiceClip> stop() async {
    started = false;
    if (stopThrows case final e?) throw e;
    return clip;
  }

  @override
  Future<void> cancel() async {
    cancels++;
    started = false;
  }

  @override
  Stream<double> amplitude() => levels.stream;

  @override
  Future<void> dispose() async {
    disposed = true;
    await levels.close();
  }
}

class _FakeTranscriber implements Transcriber {
  String? answer = 'سجل خمسين قهوة';
  Exception? failWith;
  int calls = 0;

  @override
  Future<String?> transcribe(VoiceClip clip) async {
    calls++;
    if (failWith case final e?) throw e;
    return answer;
  }
}

void main() {
  late _FakeRecorder recorder;
  late _FakeTranscriber transcriber;

  setUp(() {
    recorder = _FakeRecorder();
    transcriber = _FakeTranscriber();
  });

  ProviderContainer containerWith() => ProviderContainer(
    overrides: [
      voiceRecorderProvider.overrideWithValue(recorder),
      transcriberProvider.overrideWithValue(transcriber),
    ],
  );

  group('starting', () {
    test('records, and says so', () async {
      final container = containerWith();
      addTearDown(container.dispose);

      await container.read(voiceInputControllerProvider.notifier).start();

      final view = container.read(voiceInputControllerProvider);
      expect(view.stage, VoiceStage.recording);
      expect(recorder.started, isTrue);
    });

    test('a second press while recording does nothing', () async {
      // The habit itself. Two sessions is the bug; ignoring the second press
      // is the fix, and the visual state is what stops it being pressed.
      final container = containerWith();
      addTearDown(container.dispose);
      final controller = container.read(voiceInputControllerProvider.notifier);

      await controller.start();
      await controller.start();

      expect(recorder.starts, 1);
    });

    test('a refused microphone is named, not silent', () async {
      recorder.permitted = false;
      final container = containerWith();
      addTearDown(container.dispose);

      await container.read(voiceInputControllerProvider.notifier).start();

      expect(
        container.read(voiceInputControllerProvider).stage,
        VoiceStage.denied,
      );
      expect(recorder.started, isFalse);
    });

    test('the waveform follows the microphone', () async {
      final container = containerWith();
      addTearDown(container.dispose);

      await container.read(voiceInputControllerProvider.notifier).start();
      recorder.levels.add(0.6);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(voiceInputControllerProvider).amplitude,
        closeTo(0.6, 0.001),
      );
    });
  });

  group('finishing', () {
    test('the transcript is offered, not sent', () async {
      final container = containerWith();
      addTearDown(container.dispose);
      final controller = container.read(voiceInputControllerProvider.notifier);

      await controller.start();
      await controller.stopAndTranscribe();

      final view = container.read(voiceInputControllerProvider);
      expect(view.transcript, 'سجل خمسين قهوة');
      expect(view.stage, VoiceStage.idle);
    });

    test('taking the transcript clears it, so it cannot land twice', () async {
      final container = containerWith();
      addTearDown(container.dispose);
      final controller = container.read(voiceInputControllerProvider.notifier);

      await controller.start();
      await controller.stopAndTranscribe();
      controller.transcriptTaken();

      expect(container.read(voiceInputControllerProvider).transcript, isNull);
    });

    test('a clip that was too short becomes a nudge, not an error', () async {
      recorder.stopThrows = const VoiceClipDiscarded(VoiceDiscard.tooShort);
      final container = containerWith();
      addTearDown(container.dispose);
      final controller = container.read(voiceInputControllerProvider.notifier);

      await controller.start();
      await controller.stopAndTranscribe();

      expect(
        container.read(voiceInputControllerProvider).stage,
        VoiceStage.tooShort,
      );
      // And nothing was paid for: no round trip on a button press.
      expect(transcriber.calls, 0);
    });

    test('silence heard by Whisper reads the same as a short clip', () async {
      transcriber.answer = '   ';
      final container = containerWith();
      addTearDown(container.dispose);
      final controller = container.read(voiceInputControllerProvider.notifier);

      await controller.start();
      await controller.stopAndTranscribe();

      // The fix is the same — say it again, closer — so the words are too.
      expect(
        container.read(voiceInputControllerProvider).stage,
        VoiceStage.tooShort,
      );
    });

    test('a transcription failure is its own state', () async {
      transcriber.failWith = Exception('offline');
      final container = containerWith();
      addTearDown(container.dispose);
      final controller = container.read(voiceInputControllerProvider.notifier);

      await controller.start();
      await controller.stopAndTranscribe();

      expect(
        container.read(voiceInputControllerProvider).stage,
        VoiceStage.failed,
      );
    });

    test('stopping when nothing is recording does nothing', () async {
      final container = containerWith();
      addTearDown(container.dispose);

      await container
          .read(voiceInputControllerProvider.notifier)
          .stopAndTranscribe();

      expect(transcriber.calls, 0);
      expect(
        container.read(voiceInputControllerProvider).stage,
        VoiceStage.idle,
      );
    });
  });

  group('leaving', () {
    test('cancelling stops the capture and keeps nothing', () async {
      final container = containerWith();
      addTearDown(container.dispose);
      final controller = container.read(voiceInputControllerProvider.notifier);

      await controller.start();
      await controller.cancel();

      expect(recorder.cancels, 1);
      expect(recorder.started, isFalse);
      expect(transcriber.calls, 0);
      expect(
        container.read(voiceInputControllerProvider).stage,
        VoiceStage.idle,
      );
    });

    test('disposing the screen releases the microphone', () async {
      // A back gesture, a tab switch, a sign-out — all of them dispose the
      // provider, and none of them should leave a capture session running
      // behind a screen that has gone.
      final container = containerWith();
      await container.read(voiceInputControllerProvider.notifier).start();

      container.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(recorder.disposed, isTrue);
    });
  });
}
