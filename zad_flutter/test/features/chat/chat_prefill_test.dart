// A question another screen offers (the map's "اسأل زاد") lands in the
// composer and waits there: nothing outside the chat starts a turn.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/design/zad_theme.dart';
import 'package:zad/features/chat/application/chat_controller.dart';
import 'package:zad/features/chat/application/voice_input_controller.dart';
import 'package:zad/features/chat/presentation/chat_screen.dart';

class _Chat extends ChatController {
  final List<String> sent = <String>[];

  @override
  ChatView build() => const ChatView();

  @override
  Future<void> send(String text) async => sent.add(text);
}

class _Voice extends VoiceInputController {
  @override
  VoiceInputView build() => const VoiceInputView();
}

void main() {
  testWidgets('an offered question fills the composer and is not sent', (
    tester,
  ) async {
    final chat = _Chat();
    final container = ProviderContainer(
      overrides: [
        chatControllerProvider.overrideWith(() => chat),
        voiceInputControllerProvider.overrideWith(_Voice.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: ChatScreen(),
          ),
        ),
      ),
    );

    container
        .read(chatPrefillProvider.notifier)
        .offer('وضّحلي أكتر عن المخزون');
    await tester.pump();

    expect(find.text('وضّحلي أكتر عن المخزون'), findsOneWidget);
    expect(chat.sent, isEmpty);
    // Taken, so it is not offered twice.
    expect(container.read(chatPrefillProvider), isNull);
  });

  test('a blank offer is no offer', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(chatPrefillProvider.notifier).offer('   ');
    expect(container.read(chatPrefillProvider), isNull);
  });
}
