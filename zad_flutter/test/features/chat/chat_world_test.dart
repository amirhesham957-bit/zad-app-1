// The chat as a world: the label as the title, a state line from the
// conversation, the companion posed by what it is doing, the composer docked,
// and every control that used to be in the app bar still reachable.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/chat/presentation/chat_screen.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/ads/application/interstitials.dart';
import 'package:zad/shared/chat/application/chat_controller.dart';
import 'package:zad/shared/chat/application/voice_input_controller.dart';
import 'package:zad/shared/chat/domain/agent_turn.dart';
import 'package:zad/shared/chat/domain/chat_message.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';

import '../../support/fonts.dart';
import '../../support/quiet_household.dart';

class _Chat extends ChatController {
  new(this.initial);
  final ChatView initial;

  @override
  ChatView build() => initial;
}

class _Breaks implements Interstitials {
  @override
  Future<bool> atBreak(InterstitialBreak kind) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Voice extends VoiceInputController {
  @override
  VoiceInputView build() => const VoiceInputView();
}

ChatMessage _m(String id, String text, {required bool mine, int minute = 0}) =>
    ChatMessage(
      id: id,
      text: text,
      isUser: mine,
      createdAt: DateTime.utc(2026, 11, 20, 9, minute),
    );

Future<void> _pump(WidgetTester tester, ChatView view) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: ProviderScope(
        overrides: [
          ...quietOrbOverrides,
          adsAllowedProvider.overrideWithValue(false),
          interstitialsProvider.overrideWithValue(_Breaks()),
          chatControllerProvider.overrideWith(() => _Chat(view)),
          voiceInputControllerProvider.overrideWith(_Voice.new),
          accountTimeZoneProvider.overrideWithValue('Africa/Cairo'),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ZadTheme.light(),
          locale: const Locale('ar'),
          supportedLocales: ZadL10n.supportedLocales,
          localizationsDelegates: ZadL10n.localizationsDelegates,
          home: const ChatScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

CompanionState _pose(WidgetTester tester) =>
    tester.widget<CompanionOrb>(find.byType(CompanionOrb)).state;

void main() {
  setUpAll(tz_data.initializeTimeZones);

  testWidgets('empty: the world title, the neutral line, the welcome bubble '
      'and every control', (tester) async {
    await _pump(tester, const ChatView());
    expect(find.text('الشات'), findsOneWidget);
    expect(find.text('أنا سامعك'), findsOneWidget);
    expect(find.text(zadWelcomeMessage(zadL10nArabic).text), findsOneWidget);
    expect(_pose(tester), CompanionState.idle);
    expect(find.byTooltip('عقل زاد'), findsOneWidget);
    expect(find.byTooltip('سجّل صوت'), findsOneWidget);
    expect(find.byTooltip('ابعت'), findsOneWidget);
    // Nothing to clear yet.
    expect(find.byTooltip('ابدأ محادثة جديدة'), findsNothing);
  });

  testWidgets('a reply on its way: the line says so and the companion thinks', (
    tester,
  ) async {
    await _pump(
      tester,
      ChatView(
        isAwaitingReply: true,
        messages: [
          _m('1', 'سجل 50 جنيه قهوة', mine: true),
          ChatMessage(
            id: '2',
            text: '',
            isUser: false,
            createdAt: DateTime.utc(2026, 11, 20, 9, 1),
            status: ChatStatus.sending,
          ),
        ],
      ),
    );
    expect(find.text('بيفكّر…'), findsOneWidget);
    expect(_pose(tester), CompanionState.focused);
    expect(find.byTooltip('ابدأ محادثة جديدة'), findsOneWidget);
  });

  testWidgets('a settled conversation says how long it is', (tester) async {
    await _pump(
      tester,
      ChatView(
        messages: [
          _m('1', 'مرحبا', mine: true),
          _m('2', 'أهلاً', mine: false, minute: 1),
          _m('3', 'سجل 50 جنيه قهوة', mine: true, minute: 2),
        ],
      ),
    );
    expect(find.text('3 رسايل'), findsOneWidget);
  });

  testWidgets('screenshot: the chat world', (tester) async {
    await loadZadFonts();
    tester.view
      ..physicalSize = const Size(860, 1864)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await _pump(
      tester,
      ChatView(
        messages: [
          _m('1', 'سجل 50 جنيه قهوة', mine: true),
          ChatMessage(
            id: '2',
            text: 'سجلتها. دي تالت قهوة الأسبوع ده.',
            isUser: false,
            createdAt: DateTime.utc(2026, 11, 20, 9, 1),
            executed: const [
              AgentExecuted(
                tool: 'add_expense',
                summary: 'اتسجل مصروف: قهوة 50',
              ),
            ],
          ),
          _m('3', 'الحليب خلص عندنا', mine: true, minute: 2),
          ChatMessage(
            id: '4',
            text: 'تحب أضيف الحليب لقايمة التسوق؟',
            isUser: false,
            createdAt: DateTime.utc(2026, 11, 20, 9, 3),
            proposals: const [
              AgentProposal(tool: 'add_shopping_item', summary: 'إضافة حليب'),
            ],
          ),
        ],
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../build/screens/world_chat.png'),
    );
  }, skip: Platform.environment['ZAD_SCREENS'] != '1');
}
