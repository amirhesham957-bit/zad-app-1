// «طاقة زاد» on the chat bar: the balance is the server's, so after every
// reply the chip asks the server again instead of guessing what was spent.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/chat/presentation/chat_screen.dart';
import 'package:zad/shared/chat/application/chat_controller.dart';
import 'package:zad/shared/chat/application/voice_input_controller.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/quota/data/attempts_remote.dart';
import 'package:zad/shared/quota/domain/attempts_balance.dart';

class _Chat extends ChatController {
  @override
  ChatView build() => const ChatView();

  void awaiting({required bool on}) =>
      state = state.copyWith(isAwaitingReply: on);
}

class _Voice extends VoiceInputController {
  @override
  VoiceInputView build() => const VoiceInputView();
}

class _Remote implements AttemptsRemote {
  int left = 5;
  int calls = 0;

  @override
  Future<AttemptsBalance?> fetch({required String timeZone}) async {
    calls++;
    return AttemptsBalance(
      tier: 'free',
      left: left,
      perCycle: 5,
      nextRefillAt: DateTime.utc(2026, 10, 12, 15),
      adsEnabled: true,
    );
  }
}

void main() {
  setUpAll(tz_data.initializeTimeZones);

  testWidgets('the chip re-reads the balance once a reply is in', (
    tester,
  ) async {
    final chat = _Chat();
    final remote = _Remote();
    final container = ProviderContainer(
      overrides: [
        chatControllerProvider.overrideWith(() => chat),
        voiceInputControllerProvider.overrideWith(_Voice.new),
        attemptsRemoteProvider.overrideWithValue(remote),
        accountTimeZoneProvider.overrideWithValue('Asia/Riyadh'),
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
    await tester.pump();
    expect(find.text('٥'), findsOneWidget);
    final before = remote.calls;

    // A turn starts: nothing is re-read while it is in flight.
    chat.awaiting(on: true);
    await tester.pump();
    expect(remote.calls, before);

    // The reply lands having spent 3 (a deep analysis).
    remote.left = 2;
    chat.awaiting(on: false);
    await tester.pump();
    await tester.pump();
    expect(remote.calls, before + 1);
    expect(find.text('٢'), findsOneWidget);
  });
}
