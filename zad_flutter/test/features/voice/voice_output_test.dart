// Zad's voice: chunks play in order, the next is fetched while one plays,
// anything newer (a new reply, the microphone, stop) cuts the old one off,
// a failure is reported rather than swallowed, and the orb talks while the
// audio does.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/features/chat/application/chat_controller.dart';
import 'package:zad/features/chat/application/voice_input_controller.dart';
import 'package:zad/features/orb/application/companion_mood.dart';
import 'package:zad/features/orb/domain/companion_state.dart';
import 'package:zad/features/voice/application/voice_output_controller.dart';
import 'package:zad/features/voice/data/voice_player.dart';
import 'package:zad/features/voice/data/voice_synthesizer.dart';
import 'package:zad/features/voice/zad_voice.dart';

class _Synth implements VoiceSynthesizer {
  final requested = <String>[];
  final personas = <String?>[];
  final pending = <Completer<SpokenAudio>>[];
  bool fail = false;

  @override
  Future<SpokenAudio> synthesize(String text, {String? persona}) {
    requested.add(text);
    personas.add(persona);
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

void main() {
  late _Synth synth;
  late _Player player;
  late ProviderContainer c;

  setUp(() {
    synth = _Synth();
    player = _Player();
    c = ProviderContainer(
      overrides: [
        voiceSynthesizerProvider.overrideWithValue(synth),
        voicePlayerProvider.overrideWithValue(player),
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
    expect(synth.requested, hasLength(1));

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
          'persona': 'sarah_warm',
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

  test('the persona reaches the server, Sarah when none is saved', () async {
    final voice = c.read(voiceOutputControllerProvider.notifier);
    unawaited(voice.speak('مرحبا.', persona: 'karim_pro'));
    await settle();
    expect(synth.personas.single, 'karim_pro');

    unawaited(voice.speak('تاني.'));
    await settle();
    expect(synth.personas.last, 'sarah_warm', reason: 'no device store here');
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
      final box = await Hive.openBox<String>(
        'zad_voice_test_${DateTime.now().microsecondsSinceEpoch}',
        bytes: Uint8List(0),
      );
      final zc = ProviderContainer(
        overrides: [
          voiceSynthesizerProvider.overrideWithValue(synth),
          voicePlayerProvider.overrideWithValue(player),
          voiceInputControllerProvider.overrideWith(_Mic.new),
          chatControllerProvider.overrideWith(_Chat.new),
          zadVoiceProvider.overrideWith((ref) => ZadVoice(ref, box)),
        ],
      );
      addTearDown(zc.dispose);
      final zad = zc.read(zadVoiceProvider)..persona = 'pet_mascot';
      await settle();

      unawaited(zad.speak('مرحبا.'));
      await settle();
      expect(zad.speaking.value, isTrue, reason: 'the orb and pill see it');
      expect(synth.personas.last, 'pet_mascot', reason: 'the chosen voice');
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
}
