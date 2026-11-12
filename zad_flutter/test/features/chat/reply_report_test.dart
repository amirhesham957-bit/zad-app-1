// «بلّغ عن الرد» (ZAD_PLAN 8.3): the flag under Zad's reply opens four
// reasons, sends the reply's own id, text and the chosen reason, and tells
// the customer whether it arrived.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/features/chat/application/reply_report.dart';
import 'package:zad/features/chat/presentation/reply_report_button.dart';
import 'package:zad/shared/chat/domain/chat_message.dart';

final _reply = ChatMessage(
  id: 'reply-42',
  text: 'رد من زاد',
  isUser: false,
  createdAt: DateTime.utc(2026, 11, 13, 9),
);

typedef _Sent = ({String messageId, String text, ReplyReportReason reason});

Future<List<_Sent>> _pump(WidgetTester tester, {required bool ok}) async {
  final sent = <_Sent>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        replyReporterProvider.overrideWithValue(({
          required messageId,
          required text,
          required reason,
        }) async {
          sent.add((messageId: messageId, text: text, reason: reason));
          return ok;
        }),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: ZadL10n.localizationsDelegates,
        supportedLocales: ZadL10n.supportedLocales,
        home: Scaffold(
          body: Center(child: ReplyReportButton(message: _reply)),
        ),
      ),
    ),
  );
  return sent;
}

void main() {
  testWidgets('a reason sends the reply and thanks the customer', (
    tester,
  ) async {
    final sent = await _pump(tester, ok: true);

    await tester.tap(find.byTooltip('بلّغ عن الرد'));
    await tester.pumpAndSettle();
    expect(find.text('إيه المشكلة في الرد ده؟'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(4));

    await tester.tap(find.text('نصيحة ممكن تأذي'));
    await tester.pumpAndSettle();

    expect(sent, hasLength(1));
    expect(sent.single.messageId, 'reply-42');
    expect(sent.single.text, 'رد من زاد');
    expect(sent.single.reason, ReplyReportReason.harmful);
    expect(find.text('وصل بلاغك، شكراً. هنراجع الرد ده.'), findsOneWidget);
  });

  testWidgets('a report that did not arrive says so', (tester) async {
    await _pump(tester, ok: false);

    await tester.tap(find.byTooltip('بلّغ عن الرد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مسيء أو غير لائق'));
    await tester.pumpAndSettle();

    expect(find.text('البلاغ ماوصلش — جرّب تاني'), findsOneWidget);
  });

  testWidgets('closing the sheet sends nothing', (tester) async {
    final sent = await _pump(tester, ok: true);

    await tester.tap(find.byTooltip('بلّغ عن الرد'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(sent, isEmpty);
  });

  test("the reasons are the server's values", () {
    expect(ReplyReportReason.values.map((r) => r.name), <String>[
      'offensive',
      'wrong',
      'harmful',
      'other',
    ]);
  });
}
