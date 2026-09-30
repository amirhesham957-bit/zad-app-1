// The mic sheet: what it sends is a voice turn, and a turn that fails says
// so instead of speaking the previous answer again.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/features/voice/presentation/zad_voice_sheet.dart';
import 'package:zad/shared/chat/application/chat_controller.dart';
import 'package:zad/shared/chat/application/voice_input_controller.dart';
import 'package:zad/shared/chat/domain/chat_message.dart';
import 'package:zad/shared/voice/application/voice_output_controller.dart';
import 'package:zad/shared/voice/data/voice_openers.dart';
import 'package:zad/shared/voice/data/voice_player.dart';
import 'package:zad/shared/voice/data/voice_synthesizer.dart';

class _Chat extends ChatController {
  final sent = <(String, bool)>[];

  @override
  ChatView build() => ChatView(
    messages: <ChatMessage>[
      ChatMessage(
        id: 'old',
        text: 'الرد القديم',
        isUser: false,
        createdAt: DateTime.utc(2026, 9, 27),
      ),
    ],
  );

  @override
  Future<void> send(String raw, {bool viaVoice = false}) async {
    sent.add((raw, viaVoice));
    state = state.copyWith(
      messages: <ChatMessage>[
        ...state.messages,
        ChatMessage(
          id: 'mine',
          text: raw,
          isUser: true,
          createdAt: DateTime.utc(2026, 9, 27, 1),
        ),
      ],
      isAwaitingReply: true,
    );
  }

  void fail() => state = state.copyWith(
    isAwaitingReply: false,
    error: StateError('offline'),
  );
}

class _Mic extends VoiceInputController {
  @override
  VoiceInputView build() => const VoiceInputView();
}

class _Synth implements VoiceSynthesizer {
  final requested = <String>[];

  @override
  Future<SpokenAudio> synthesize(String text) {
    requested.add(text);
    return Completer<SpokenAudio>().future;
  }
}

/// Every opener already kept: the sheet's warm-up asks for nothing.
class _Kept implements VoiceOpenerStore {
  @override
  Future<Uint8List?> read(String key) async => Uint8List(4);

  @override
  Future<void> write(String key, Uint8List pcm) async {}
}

class _Player implements VoicePlayer {
  @override
  Future<void> play(Uint8List wav) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  late _Chat chat;
  late _Synth synth;
  late Directory dir;
  late ZadLocalStore store;

  // The orb and the persona read the device box; opened here, never inside
  // testWidgets, where a Hive write never completes.
  setUp(() async {
    chat = _Chat();
    synth = _Synth();
    dir = await Directory.systemTemp.createTemp('zad_voice_sheet_test');
    Hive.init(dir.path);
    store = await ZadLocalStore.open();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatControllerProvider.overrideWith(() => chat),
          voiceInputControllerProvider.overrideWith(_Mic.new),
          voiceSynthesizerProvider.overrideWithValue(synth),
          voicePlayerProvider.overrideWithValue(_Player()),
          voiceOpenersProvider.overrideWith(
            (ref) => VoiceOpeners(ref.watch(voiceSynthesizerProvider), _Kept()),
          ),
          localStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: ZadVoiceSheet()),
          ),
        ),
      ),
    );
  }

  testWidgets('a question from the sheet goes out as a voice turn', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('حلل مصاريفي'));
    await tester.pump();

    expect(chat.sent, <(String, bool)>[('حلل مصاريفي', true)]);
  });

  testWidgets('a failed turn says so and never re-speaks the last answer', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('حلل مصاريفي'));
    await tester.pump();

    chat.fail();
    await tester.pump();

    expect(find.textContaining('ماقدرتش أوصل لعقل زاد'), findsOneWidget);
    expect(synth.requested, isEmpty, reason: 'nothing spoken, old reply least');
  });

  testWidgets('waiting for the answer reads as thinking, not as talking', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('حلل مصاريفي'));
    await tester.pump();
    // What the chat does for a voice turn: the reply's speech is set up at
    // once, before a word of it exists.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ZadVoiceSheet)),
    );
    container
        .read(voiceOutputControllerProvider.notifier)
        .speakStreaming(opener: true);
    await tester.pump();
    await tester.pump();

    expect(find.text('زاد بيتكلم…'), findsNothing);
    expect(find.text('بيفكر…'), findsOneWidget);
  });
}
