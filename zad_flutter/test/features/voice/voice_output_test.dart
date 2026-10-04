// Zad's voice: chunks play in order, the next is fetched while one plays,
// anything newer (a new reply, the microphone, stop) cuts the old one off,
// a failure is reported rather than swallowed, and the orb talks while the
// audio does.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/shared/chat/application/chat_controller.dart';
import 'package:zad/shared/chat/application/voice_input_controller.dart';
import 'package:zad/shared/orb/application/companion_mood.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/voice/application/voice_output_controller.dart';
import 'package:zad/shared/voice/application/zad_voice.dart';
import 'package:zad/shared/voice/data/voice_openers.dart';
import 'package:zad/shared/voice/data/voice_player.dart';
import 'package:zad/shared/voice/data/voice_synthesizer.dart';
import 'package:zad/shared/voice/domain/speech_text.dart';

class _Synth implements VoiceSynthesizer {
  final requested = <String>[];
  final feelings = <String?>[];
  final pending = <Completer<SpokenAudio>>[];
  bool fail = false;

  @override
  Future<SpokenAudio> synthesize(String text, {String? feelingFrom}) {
    requested.add(text);
    feelings.add(feelingFrom);
    if (fail) return Future<SpokenAudio>.error(StateError('502'));
    final c = Completer<SpokenAudio>();
    pending.add(c);
    return c.future;
  }

  void answer(int i, [String provider = 'gemini']) => pending[i].complete((
    pcm: Uint8List.fromList(utf8.encode('pcm$i')),
    provider: provider,
  ));
}

class _Player implements VoicePlayer {
  final played = <Uint8List>[];
  Completer<void>? current;
  int stops = 0;

  @override
  Future<void> play(Uint8List wav) {
    played.add(wav);
    return (current = Completer<void>()).future;
  }

  void finish() {
    if (current case final c? when !c.isCompleted) c.complete();
  }

  @override
  Future<void> stop() async {
    stops++;
    if (current case final c? when !c.isCompleted) c.complete();
  }

  @override
  Future<void> dispose() async {}
}

class _PreparingPlayer extends _Player implements PreparingVoicePlayer {
  final prepared = <Uint8List>[];

  @override
  Future<void> prepare(Uint8List wav) async => prepared.add(wav);
}

class _Chat extends ChatController {
  @override
  ChatView build() => const ChatView();
}

class _Mic extends VoiceInputController {
  @override
  VoiceInputView build() => const VoiceInputView();

  void recording() => state = const VoiceInputView(stage: VoiceStage.recording);
}

String _pcmOf(Uint8List wav) => utf8.decode(wav.sublist(44));

class _Kept implements VoiceOpenerStore {
  final Map<String, Uint8List> files = <String, Uint8List>{};

  @override
  Future<Uint8List?> read(String key) async => files[key];

  @override
  Future<void> write(String key, Uint8List pcm) async => files[key] = pcm;
}

void main() {
  late _Synth synth;
  late _Player player;
  late ProviderContainer c;

  late _Kept kept;

  setUp(() {
    synth = _Synth();
    player = _Player();
    kept = _Kept();
    c = ProviderContainer(
      overrides: [
        voiceSynthesizerProvider.overrideWithValue(synth),
        voicePlayerProvider.overrideWithValue(player),
        voiceOpenersProvider.overrideWith(
          (ref) => VoiceOpeners(ref.watch(voiceSynthesizerProvider), kept),
        ),
        voiceInputControllerProvider.overrideWith(_Mic.new),
        chatControllerProvider.overrideWith(_Chat.new),
      ],
    );
    addTearDown(c.dispose);
  });

  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  const reply =
      'أول جملة طويلة شوية عشان تبقى لوحدها في حتة. '
      'تاني جملة طويلة شوية برضه عشان تبقى لوحدها في حتة تانية خالص '
      'ومش تتلم مع الأولى في نفس الطلب أبداً لأنها طويلة كفاية فعلاً '
      'زيادة عن اللزوم يعني وكمان شوية كمان شوية عشان نعدي المية.';

  test('plays in order, fetching the next chunk while one plays', () async {
    final voice = c.read(voiceOutputControllerProvider.notifier);
    final done = voice.speak('$reply $reply', messageId: 'm1');
    await settle();
    expect(
      c.read(voiceOutputControllerProvider).stage,
      VoiceOutputStage.preparing,
    );
    // The first chunk and the one after it are asked for together.
    expect(synth.requested, hasLength(2));

    synth.answer(0, 'azure');
    await settle();
    final view = c.read(voiceOutputControllerProvider);
    expect(view.stage, VoiceOutputStage.speaking);
    expect(view.messageId, 'm1');
    expect(view.provider, 'azure');
    expect(_pcmOf(player.played.single), 'pcm0');
    // The second request is out while the first chunk is still playing.
    expect(synth.requested.length, greaterThan(1));

    var finished = false;
    unawaited(done.then((_) => finished = true));
    for (var n = 0; n < 50 && !finished; n++) {
      for (var i = 0; i < synth.pending.length; i++) {
        if (!synth.pending[i].isCompleted) synth.answer(i);
      }
      player.finish();
      await settle();
    }
    expect(finished, isTrue);
    expect(synth.requested.length, greaterThan(1));
    expect(player.played.map(_pcmOf).toList(), <String>[
      for (var i = 0; i < synth.requested.length; i++) 'pcm$i',
    ]);
    expect(c.read(voiceOutputControllerProvider).stage, VoiceOutputStage.idle);
  });

  test('stop cuts it off; nothing more plays', () async {
    final voice = c.read(voiceOutputControllerProvider.notifier);
    final done = voice.speak('$reply $reply');
    await settle();
    synth.answer(0);
    await settle();
    await voice.stop();
    for (var i = 1; i < synth.requested.length; i++) {
      synth.answer(i);
    }
    await done;
    await settle();
    expect(player.played, hasLength(1));
    expect(c.read(voiceOutputControllerProvider).isActive, isFalse);
  });

  test('a new reply is not reset by the one it interrupted', () async {
    final voice = c.read(voiceOutputControllerProvider.notifier);
    unawaited(voice.speak('أول رد.', messageId: 'a'));
    await settle();
    synth.answer(0);
    await settle(); // "a" is playing its only chunk

    unawaited(voice.speak('تاني رد.', messageId: 'b'));
    await settle(); // stopping "a" ended its play() — it must bow out

    final view = c.read(voiceOutputControllerProvider);
    expect(view.messageId, 'b');
    expect(view.stage, VoiceOutputStage.preparing);
  });

  test('the microphone interrupts Zad', () async {
    final voice = c.read(voiceOutputControllerProvider.notifier);
    unawaited(voice.speak(reply));
    await settle();
    synth.answer(0);
    await settle();
    expect(c.read(voiceOutputControllerProvider).isActive, isTrue);

    (c.read(voiceInputControllerProvider.notifier) as _Mic).recording();
    await settle();
    expect(c.read(voiceOutputControllerProvider).isActive, isFalse);
    expect(player.stops, greaterThan(1));
  });

  test('a failure is reported, not swallowed', () async {
    synth.fail = true;
    await c.read(voiceOutputControllerProvider.notifier).speak('مرحبا.');
    final view = c.read(voiceOutputControllerProvider);
    expect(view.failed, isTrue);
    expect(view.isActive, isFalse);
    expect(player.played, isEmpty);
  });

  test('the orb talks while the audio does', () async {
    c.listen(companionMoodProvider, (_, _) {});
    final voice = c.read(voiceOutputControllerProvider.notifier);
    unawaited(voice.speak('مرحبا.'));
    await settle();
    expect(c.read(companionMoodProvider), CompanionState.focused);
    synth.answer(0);
    await settle();
    expect(c.read(companionMoodProvider), CompanionState.speaking);
    player.finish();
    await settle();
    expect(c.read(companionMoodProvider), isNot(CompanionState.speaking));
  });

  group('SupabaseVoiceSynthesizer', () {
    final supabase = SupabaseClient('https://example.supabase.co', 'anon');

    test(
      'asks voice_synthesize for Sarah and returns PCM + provider',
      () async {
        http.Request? sent;
        final synth = SupabaseVoiceSynthesizer(
          supabase,
          clientFactory: () => MockClient((request) async {
            sent = request;
            return http.Response.bytes(
              <int>[1, 2, 3, 4],
              200,
              headers: <String, String>{'x-zad-voice-provider': 'azure'},
            );
          }),
        );
        final audio = await synth.synthesize('أهلاً');
        expect(audio.pcm, <int>[1, 2, 3, 4]);
        expect(audio.provider, 'azure');
        final body = jsonDecode(sent!.body) as Map<String, dynamic>;
        expect(body['action'], 'voice_synthesize');
        expect(body['payload'], <String, dynamic>{
          'text': 'أهلاً',
          'persona': 'zad',
        });
        expect(sent!.url.path, endsWith('/functions/v1/zad-core-intelligence'));
      },
    );

    test('a non-200 is an error with the server reason', () async {
      final synth = SupabaseVoiceSynthesizer(
        supabase,
        clientFactory: () => MockClient(
          (_) async =>
              http.Response('{"error":"voice provider unavailable"}', 502),
        ),
      );
      await expectLater(
        synth.synthesize('أهلاً'),
        throwsA(
          isA<http.ClientException>().having(
            (e) => e.message,
            'message',
            contains('502'),
          ),
        ),
      );
    });
  });

  test('every request asks for Zad, the one voice', () async {
    unawaited(c.read(voiceOutputControllerProvider.notifier).speak('مرحبا.'));
    await settle();
    expect(synth.requested, hasLength(1));
  });

  test('the playing chunk carries its loudness', () async {
    unawaited(c.read(voiceOutputControllerProvider.notifier).speak('مرحبا.'));
    await settle();
    // Two samples at full scale: loud.
    synth.pending.single.complete((
      pcm: Uint8List.fromList(<int>[0xFF, 0x7F, 0xFF, 0x7F]),
      provider: 'gemini',
    ));
    await settle();
    expect(c.read(voiceOutputControllerProvider).level, greaterThan(0.9));
    expect(pcmLoudness(Uint8List(8)), 0, reason: 'silence');
  });

  test(
    'ZadVoice goes through the same player, so stop is a real stop',
    () async {
      final zc = ProviderContainer(
        overrides: [
          voiceSynthesizerProvider.overrideWithValue(synth),
          voicePlayerProvider.overrideWithValue(player),
          voiceInputControllerProvider.overrideWith(_Mic.new),
          chatControllerProvider.overrideWith(_Chat.new),
        ],
      );
      addTearDown(zc.dispose);
      final zad = zc.read(zadVoiceProvider);
      await settle();

      unawaited(zad.speak('مرحبا.'));
      await settle();
      expect(zad.speaking.value, isTrue, reason: 'the orb and pill see it');
      synth.answer(synth.pending.length - 1);
      await settle();
      expect(player.played, isNotEmpty);

      final stopsBefore = player.stops;
      zad.stop();
      await settle();
      expect(
        player.stops,
        greaterThan(stopsBefore),
        reason: 'the player stops',
      );
      expect(zad.speaking.value, isFalse);
    },
  );

  test(
    'the next chunk is loaded while this one plays, then played as is',
    () async {
      final preparing = _PreparingPlayer();
      final pc = ProviderContainer(
        overrides: [
          voiceSynthesizerProvider.overrideWithValue(synth),
          voicePlayerProvider.overrideWithValue(preparing),
          voiceInputControllerProvider.overrideWith(_Mic.new),
          chatControllerProvider.overrideWith(_Chat.new),
        ],
      );
      addTearDown(pc.dispose);
      unawaited(
        pc
            .read(voiceOutputControllerProvider.notifier)
            .speak('$reply $reply', messageId: 'm1'),
      );
      await settle();
      synth.answer(0);
      await settle();
      expect(preparing.played, hasLength(1));
      // Chunk 1 arrives while chunk 0 is still playing: it is loaded now…
      synth.answer(1);
      await settle();
      expect(preparing.prepared.map(_pcmOf), <String>['pcm1']);
      // …and when chunk 0 ends, the very same bytes are played.
      preparing.finish();
      await settle();
      expect(preparing.played, hasLength(2));
      expect(identical(preparing.played[1], preparing.prepared.single), isTrue);
    },
  );

  group('a spoken question (owner, 2026-10-01: «بيرد بعد دقيقة»)', () {
    // Five sentences past the chunk size: five chunks.
    final sentences = <String>[
      for (var i = 0; i < 5; i++)
        'جملة رقم $i ${'فيها كلام كتير ' * 14}عشان تبقى حتة لوحدها.',
    ];

    test(
      'every released chunk is asked for at once, three at a time',
      () async {
        final speech = c
            .read(voiceOutputControllerProvider.notifier)
            .speakStreaming(messageId: 'm');
        expect(sentences.first.length, greaterThan(chunkTarget));
        speech
          ..add(sentences.join(' '))
          ..finish();
        await settle();
        // Nothing has come back yet, and three requests are already out —
        // the second used to wait for the first one's audio.
        expect(synth.requested, hasLength(3));
        expect(player.played, isEmpty);

        synth.answer(0);
        await settle();
        expect(synth.requested, hasLength(4), reason: 'a slot came free');
        expect(_pcmOf(player.played.single), 'pcm0');

        var n = 0;
        while (c.read(voiceOutputControllerProvider).isActive && n++ < 50) {
          for (var i = 0; i < synth.pending.length; i++) {
            if (!synth.pending[i].isCompleted) synth.answer(i);
          }
          player.finish();
          await settle();
        }
        expect(player.played.map(_pcmOf).toList(), <String>[
          for (var i = 0; i < synth.requested.length; i++) 'pcm$i',
        ]);
      },
    );

    test(
      'every chunk of a reply carries its first chunk for the feeling',
      () async {
        c
            .read(voiceOutputControllerProvider.notifier)
            .speakStreaming(messageId: 'm')
          ..add(sentences.join(' '))
          ..finish();
        await settle();
        expect(synth.requested, hasLength(3));
        expect(synth.feelings, everyElement(synth.requested.first));
      },
    );

    test(
      'a kept opener plays at once; the answer waits for it to end',
      () async {
        kept.files[VoiceOpeners.keyOf(voiceOpenerLines.first)] =
            Uint8List.fromList(utf8.encode('opener'));
        final speech = c
            .read(voiceOutputControllerProvider.notifier)
            .speakStreaming(opener: true);
        await settle();
        expect(player.played.map(_pcmOf), <String>['opener']);
        expect(
          c.read(voiceOutputControllerProvider).stage,
          VoiceOutputStage.preparing,
          reason: 'the opener is not the answer',
        );

        speech
          ..add('${sentences.first} ')
          ..finish();
        await settle();
        synth.answer(0);
        await settle();
        expect(player.played, hasLength(1), reason: 'the opener is not cut');

        player.finish();
        await settle();
        expect(player.played.map(_pcmOf), <String>['opener', 'pcm0']);
      },
    );

    test('no opener kept: silence until the answer, never a wait', () async {
      final speech = c
          .read(voiceOutputControllerProvider.notifier)
          .speakStreaming(opener: true);
      await settle();
      expect(player.played, isEmpty);
      speech
        ..add(sentences.first)
        ..finish();
      await settle();
      synth.answer(0);
      await settle();
      expect(player.played.map(_pcmOf), <String>['pcm0']);
    });

    test(
      'warmUp keeps each line once, and stops at the first failure',
      () async {
        final openers = VoiceOpeners(synth, kept);
        final warming = openers.warmUp();
        await settle();
        synth.answer(0);
        await settle();
        synth.answer(1);
        await settle();
        synth.answer(2);
        await warming;
        expect(synth.requested, voiceOpenerLines);
        expect(kept.files, hasLength(voiceOpenerLines.length));
        expect(await openers.pick(), isNotNull);

        await openers.warmUp();
        expect(synth.requested, hasLength(3), reason: 'nothing asked again');

        final failing = _Synth()..fail = true;
        final empty = _Kept();
        await VoiceOpeners(failing, empty).warmUp();
        expect(failing.requested, hasLength(1));
        expect(empty.files, isEmpty);
      },
    );

    const perVoice =
        "the lines are kept per chosen voice: a boy's voice never plays a "
        "girl's line, and a girl's lines keep the key they always had";
    test(perVoice, () async {
      // A girl's voice keeps the key lines were kept under before the choice.
      final before = voiceOpenerLines.first.codeUnits.fold<int>(
        7,
        (h, c) => (h * 31 + c) & 0x7fffffff,
      );
      expect(VoiceOpeners.keyOf(voiceOpenerLines.first), 'opener_$before');
      expect(
        VoiceOpeners.keyOf(voiceOpenerLines.first, voice: 'male'),
        isNot(VoiceOpeners.keyOf(voiceOpenerLines.first)),
      );

      var voice = 'female';
      final openers = VoiceOpeners(synth, kept, voice: () => voice);
      for (final line in voiceOpenerLines) {
        kept.files[VoiceOpeners.keyOf(line)] = Uint8List.fromList(
          utf8.encode('girl'),
        );
      }
      expect(await openers.pick(), isNotNull);

      voice = 'male';
      expect(await openers.pick(), isNull, reason: 'none kept in his voice');
      final warming = openers.warmUp();
      await settle();
      synth.answer(0);
      await settle();
      synth.answer(1);
      await settle();
      synth.answer(2);
      await warming;
      expect(synth.requested, voiceOpenerLines);
      expect(utf8.decode((await openers.pick())!), isNot('girl'));
    });
  });
}
