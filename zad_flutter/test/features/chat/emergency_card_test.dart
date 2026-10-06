// حارس الطوارئ المنزلية (الشريحة ٤٣): رسالة فيها طوارئ بيت ⇒ كارت فوق
// خانة الكتابة يفتح الفنيين بنقرة، والصنعة المطلوبة الأول.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/chat/presentation/chat_screen.dart';
import 'package:zad/shared/chat/application/chat_controller.dart';
import 'package:zad/shared/chat/application/voice_input_controller.dart';
import 'package:zad/shared/household/domain/home_emergency.dart';
import 'package:zad/shared/navigation/zad_screens.dart';

class _Chat extends ChatController {
  final List<String> sent = <String>[];

  @override
  ChatView build() => const ChatView();

  @override
  Future<void> send(String text, {bool viaVoice = false}) async =>
      sent.add(text);
}

class _Voice extends VoiceInputController {
  @override
  VoiceInputView build() => const VoiceInputView();
}

void main() {
  late List<String?> opened;
  late Future<void> Function(BuildContext, {String? trade}) wired;

  setUp(() {
    opened = <String?>[];
    wired = ZadScreens.showTrustedTechnicians;
    ZadScreens.showTrustedTechnicians = (context, {trade}) async =>
        opened.add(trade);
  });
  tearDown(() => ZadScreens.showTrustedTechnicians = wired);

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        chatControllerProvider.overrideWith(_Chat.new),
        voiceInputControllerProvider.overrideWith(_Voice.new),
      ],
      child: MaterialApp(
        theme: ZadTheme.light(),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: ChatScreen(),
        ),
      ),
    ),
  );

  Future<void> say(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
  }

  testWidgets('a leak brings the card; one tap opens the plumbers first', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byType(EmergencyTechniciansCard), findsNothing);

    await say(tester, 'المية بتنزل من السقف');
    expect(find.byType(EmergencyTechniciansCard), findsOneWidget);
    await tester.tap(find.text('فنييني'));
    await tester.pump();
    expect(opened, <String?>['plumber']);

    await tester.tap(find.byTooltip('إخفاء'));
    await tester.pump();
    expect(find.byType(EmergencyTechniciansCard), findsNothing);
  });

  testWidgets('gas says the safety line first', (tester) async {
    await pump(tester);
    await say(tester, 'فيه ريحة غاز');
    expect(find.text(kGasSafetyLine), findsOneWidget);
  });

  testWidgets('an ordinary message brings nothing', (tester) async {
    await pump(tester);
    await say(tester, 'اشتري ميه معدنية');
    expect(find.byType(EmergencyTechniciansCard), findsNothing);
  });
}
