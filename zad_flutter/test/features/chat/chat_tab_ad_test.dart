// The chat tab puts one inline ad under a reply that lands in this run, and
// none under the history it opened with.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/chat/presentation/intelligence_chat_card.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/ads/application/interstitials.dart';
import 'package:zad/shared/ads/presentation/inline_ad.dart';
import 'package:zad/shared/chat/application/chat_controller.dart';
import 'package:zad/shared/chat/application/voice_input_controller.dart';
import 'package:zad/shared/chat/domain/chat_message.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';

class _Chat extends ChatController {
  new(this.initial);

  final ChatView initial;

  @override
  ChatView build() => initial;

  // ignore: use_setters_to_change_properties, a test driver, not a property.
  void push(ChatView v) => state = v;
}

class _Breaks implements Interstitials {
  final List<InterstitialBreak> seen = <InterstitialBreak>[];

  @override
  Future<bool> atBreak(InterstitialBreak kind) async {
    seen.add(kind);
    return false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Voice extends VoiceInputController {
  @override
  VoiceInputView build() => const VoiceInputView();
}

ChatMessage _msg(String id, {required bool user}) => ChatMessage(
  id: id,
  text: 'text $id',
  isUser: user,
  createdAt: DateTime.utc(2026, 11, 14, 10),
);

void main() {
  setUpAll(tz_data.initializeTimeZones);

  late Directory dir;
  late ZadLocalStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_chat_ad_test');
    Hive.init(dir.path);
    store = await ZadLocalStore.open();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  Future<_Chat> mount(WidgetTester tester, List<ChatMessage> messages) async {
    final chat = _Chat(ChatView(messages: messages));
    final container = ProviderContainer(
      overrides: [
        chatControllerProvider.overrideWith(() => chat),
        voiceInputControllerProvider.overrideWith(_Voice.new),
        accountTimeZoneProvider.overrideWithValue('Asia/Riyadh'),
        localStoreProvider.overrideWithValue(store),
        // The widget still mounts when ads are off; it just takes no room,
        // so nothing here touches the ads SDK.
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
            child: Scaffold(body: ChatTab()),
          ),
        ),
      ),
    );
    await tester.pump();
    return chat;
  }

  testWidgets('a reply that lands in this run gets an inline ad', (
    tester,
  ) async {
    final u1 = _msg('u1', user: true);
    final chat = await mount(tester, [u1]);
    expect(find.byType(ZadInlineAd), findsNothing);

    chat.push(chat.initial.copyWith(messages: [u1], isAwaitingReply: true));
    await tester.pump();
    chat.push(
      chat.initial.copyWith(
        messages: [u1, _msg('r1', user: false)],
        isAwaitingReply: false,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(ZadInlineAd), findsOneWidget);
  });

  testWidgets('history the tab opened with gets no ad', (tester) async {
    await mount(tester, [_msg('u1', user: true), _msg('r1', user: false)]);
    await tester.pump();

    expect(find.byType(ZadInlineAd), findsNothing);
  });
}
