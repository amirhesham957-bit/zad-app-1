// The occasion card (slice 22): on the day, a greeting and one thing زاد
// does in one tap; once acted on or put away, gone until the next occasion.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/home/application/quiet_mode.dart';
import 'package:zad/features/home/presentation/occasion_card.dart';
import 'package:zad/shared/brain/domain/life_circumstance.dart';
import 'package:zad/shared/brain/domain/occasion.dart';
import 'package:zad/shared/chat/application/chat_controller.dart';
import 'package:zad/shared/navigation/zad_slots.dart';

class _Chat extends ChatController {
  final sent = <String>[];

  @override
  ChatView build() => const ChatView();

  @override
  Future<void> send(String raw, {bool viaVoice = false}) async => sent.add(raw);
}

void main() {
  group('which occasion', () {
    test("New Year offers the year's financial goals plan", () {
      final o = occasionOn(DateTime(2027))!;
      expect(o.kind, OccasionKind.newYear);
      expect(o.id, 'newYear:2027-01-01');
      expect(o.question, contains('لسنة 2027 بنقرة واحدة'));
      expect(o.prompt, contains('خطة أهداف مالية لسنة 2027'));
    });

    test('the Hijri days are Umm al-Qura, as on the server', () {
      expect(occasionOn(DateTime(2027, 2, 8))?.kind, OccasionKind.ramadan);
      expect(occasionOn(DateTime(2027, 3, 9))?.kind, OccasionKind.eidFitr);
      expect(occasionOn(DateTime(2027, 5, 16))?.kind, OccasionKind.eidAdha);
      expect(occasionOn(DateTime(2027, 6, 6))?.kind, OccasionKind.hijriNewYear);
      expect(occasionOn(DateTime(2027, 3, 21))?.kind, OccasionKind.mothersDay);
    });

    test('an ordinary day has none', () {
      expect(occasionOn(DateTime(2026, 10, 4)), isNull);
      expect(occasionOn(DateTime(2027, 2, 9)), isNull, reason: "Ramadan's 2nd");
    });

    test('the Gulf hears its own words', () {
      expect(
        occasionOn(DateTime(2027), country: 'SA')!.question,
        contains('بضغطة وحدة'),
      );
      expect(
        occasionOn(DateTime(2027), country: 'EG')!.question,
        contains('بنقرة واحدة'),
      );
    });
  });

  group('the card', () {
    late _Chat chat;

    Future<void> pump(
      WidgetTester tester,
      Occasion? today, {
      LifeCircumstance? quiet,
    }) async {
      chat = _Chat();
      ZadSlots.chatScreen = () => const Scaffold(body: Text('الشات'));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            occasionTodayProvider.overrideWithValue(today),
            chatControllerProvider.overrideWith(() => chat),
            quietModeProvider.overrideWith((ref) async => quiet),
          ],
          child: const MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(body: OccasionCardSlot()),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('one tap sends the request to زاد and opens the chat', (
      tester,
    ) async {
      await pump(tester, occasionOn(DateTime(2027)));
      expect(find.text('سنة جديدة سعيدة! 🎉'), findsOneWidget);
      await tester.tap(find.text('جهّزها'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(chat.sent.single, contains('خطة أهداف مالية لسنة 2027'));
      expect(find.text('الشات'), findsOneWidget);
    });

    testWidgets('a home in a quiet period gets no celebration', (tester) async {
      await pump(
        tester,
        occasionOn(DateTime(2027)),
        quiet: LifeCircumstance(
          id: 'c1',
          kind: 'exceptional',
          endsAt: DateTime.utc(2027, 1, 3),
        ),
      );
      await tester.pump();
      expect(find.text('سنة جديدة سعيدة! 🎉'), findsNothing);
    });

    testWidgets('«مش دلوقتي» puts it away, and nothing is sent', (
      tester,
    ) async {
      await pump(tester, occasionOn(DateTime(2027, 2, 8)));
      expect(find.text('رمضان كريم 🌙'), findsOneWidget);
      await tester.tap(find.text('مش دلوقتي'));
      await tester.pump();
      expect(find.text('رمضان كريم 🌙'), findsNothing);
      expect(chat.sent, isEmpty);
    });

    testWidgets('no occasion, no card', (tester) async {
      await pump(tester, null);
      expect(find.byType(FilledButton), findsNothing);
    });
  });
}
