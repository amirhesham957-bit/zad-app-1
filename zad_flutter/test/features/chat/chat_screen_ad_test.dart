// One ad per AI request (owner, 15/11): while the reply is pending on the
// chat screen there is exactly one inline ad, under the thinking bubble; when
// the reply lands the answer's own ad takes over, never two at once.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/chat/presentation/chat_screen.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/ads/application/interstitials.dart';
import 'package:zad/shared/ads/presentation/ai_wait_ad.dart';
import 'package:zad/shared/ads/presentation/inline_ad.dart';
import 'package:zad/shared/chat/application/chat_controller.dart';
import 'package:zad/shared/chat/application/voice_input_controller.dart';
import 'package:zad/shared/chat/domain/chat_message.dart';

class _Chat extends ChatController {
  @override
  ChatView build() =>
      ChatView(messages: <ChatMessage>[_mine, _pending], isAwaitingReply: true);

  // ignore: use_setters_to_change_properties, a test driver, not a property.
  void push(ChatView v) => state = v;
}

class _Voice extends VoiceInputController {
  @override
  VoiceInputView build() => const VoiceInputView();
}

class _Breaks implements Interstitials {
  @override
  Future<bool> atBreak(InterstitialBreak kind) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final ChatMessage _mine = ChatMessage(
  id: 'u1',
  text: 'سؤال',
  isUser: true,
  createdAt: DateTime.utc(2026, 11, 15, 10),
);

final ChatMessage _pending = ChatMessage(
  id: 'r1',
  text: '',
  isUser: false,
  createdAt: DateTime.utc(2026, 11, 15, 10),
  status: ChatStatus.sending,
);

void main() {
  testWidgets('a pending reply carries one ad; the landed one takes over', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        chatControllerProvider.overrideWith(_Chat.new),
        voiceInputControllerProvider.overrideWith(_Voice.new),
        adsAllowedProvider.overrideWithValue(false),
        interstitialsProvider.overrideWithValue(_Breaks()),
      ],
    );
    addTearDown(container.dispose);
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
    await tester.pump();
    expect(find.byType(ZadAiWaitAd), findsOneWidget);

    (container.read(chatControllerProvider.notifier) as _Chat).push(
      ChatView(
        messages: <ChatMessage>[
          _mine,
          _pending.copyWith(text: 'الرد', status: ChatStatus.done),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(ZadInlineAd), findsOneWidget);
  });
}
