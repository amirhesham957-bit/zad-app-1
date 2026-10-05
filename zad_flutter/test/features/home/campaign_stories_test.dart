// «حكايات زاد» (migration 20261005160000): the occasion's story at the top of
// home — slides that move on their own or by a tap, and one ask at the bottom
// that goes to زاد only when tapped or swiped up.
//
// Disk writes stay in setUp or in runAsync: a Hive write inside a testWidgets
// body never completes under the faked clock.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/home/application/home_campaign.dart';
import 'package:zad/features/home/presentation/campaign_stories.dart';
import 'package:zad/shared/campaigns/domain/campaign.dart';
import 'package:zad/shared/chat/application/chat_controller.dart';
import 'package:zad/shared/navigation/shell_navigation.dart';

import '../../support/quiet_household.dart';

Map<String, dynamic> _row({List<Object?>? slides}) => <String, dynamic>{
  'id': 'wf',
  'event_key': 'white_friday',
  'event_name': 'الوايت فرايداي',
  'from_md': '11-20',
  'to_md': '11-30',
  'theme_primary': '#111827',
  'theme_secondary': '#854D0E',
  'badge': '🛍️',
  'banner_title': 't',
  'banner_body': 'b',
  'cta_text': 'جهّزلي ميزانية العروض',
  'cta_prompt': 'حطلي سقف صرف للعروض.',
  'story_slides':
      slides ??
      <Object?>[
        <String, String>{'emoji': '🛍️', 'text': 'اكتب الناقص فعلاً.'},
        <String, String>{'emoji': '📏', 'text': 'حط سقف للصرف.'},
        <String, String>{'emoji': '⏳', 'text': 'استنى ٢٤ ساعة.'},
      ],
};

ActiveCampaign _active([List<Object?>? slides]) => ActiveCampaign(
  campaign: Campaign.fromJson(_row(slides: slides))!,
  start: DateTime.utc(2026, 11, 20),
  end: DateTime.utc(2026, 11, 30),
);

class _Chat extends ChatController {
  final List<String> sent = <String>[];

  @override
  ChatView build() => const ChatView();

  @override
  Future<void> send(String text, {bool viaVoice = false}) async =>
      sent.add(text);
}

void main() {
  late Directory dir;
  late Box<String> box;
  var run = 0;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_stories');
    Hive.init(dir.path);
    box = await Hive.openBox<String>('b${run++}');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  Future<(ProviderContainer, _Chat)> pump(
    WidgetTester tester,
    ActiveCampaign? active, {
    bool still = true,
  }) async {
    final chat = _Chat();
    final c = ProviderContainer(
      overrides: [
        ...quietHouseholdOverrides,
        localStoreProvider.overrideWithValue(
          ZadLocalStore(
            outbox: box,
            transactions: box,
            documents: box,
            chat: box,
            inventory: box,
            shopping: box,
            pharmacy: box,
            subscriptions: box,
            device: box,
          ),
        ),
        homeCampaignProvider.overrideWithValue(active),
        chatControllerProvider.overrideWith(() => chat),
      ],
    );
    addTearDown(c.dispose);
    tester.view
      ..physicalSize = const Size(400, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: ZadTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: still),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            ),
          ),
          home: const Scaffold(body: CampaignStoriesStrip()),
        ),
      ),
    );
    return (c, chat);
  }

  Future<void> openStory(WidgetTester tester) async {
    // Opening marks it seen on the device: real time for the write.
    await tester.runAsync(() async {
      await tester.tap(find.text('الوايت فرايداي'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('a circle named for the occasion', (tester) async {
    await pump(tester, _active());
    expect(find.text('الوايت فرايداي'), findsOneWidget);
    expect(find.text('🛍️'), findsOneWidget);
  });

  testWidgets('no slides, no circle', (tester) async {
    await pump(tester, _active(<Object?>[]));
    expect(find.text('الوايت فرايداي'), findsNothing);
    await pump(tester, null);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('a tap moves on; the start side goes back', (tester) async {
    await pump(tester, _active());
    await openStory(tester);
    expect(find.text('اكتب الناقص فعلاً.'), findsOneWidget);
    await tester.tapAt(const Offset(200, 400)); // the middle: on
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('حط سقف للصرف.'), findsOneWidget);
    await tester.tapAt(const Offset(380, 400)); // RTL start (right): back
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('اكتب الناقص فعلاً.'), findsOneWidget);
  });

  testWidgets('under reduced motion it waits for the customer', (tester) async {
    await pump(tester, _active());
    await openStory(tester);
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('اكتب الناقص فعلاً.'), findsOneWidget);
  });

  testWidgets('otherwise each slide moves on by itself', (tester) async {
    await pump(tester, _active(), still: false);
    await openStory(tester);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('حط سقف للصرف.'), findsOneWidget);
  });

  testWidgets('the button asks زاد and opens the chat; opening did not', (
    tester,
  ) async {
    final (c, chat) = await pump(tester, _active());
    await openStory(tester);
    expect(chat.sent, isEmpty);
    await tester.tap(find.text('جهّزلي ميزانية العروض'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(chat.sent, <String>['حطلي سقف صرف للعروض.']);
    expect(c.read(shellNavigationProvider), ShellTab.chat);
  });

  testWidgets('swiping up asks too', (tester) async {
    final (_, chat) = await pump(tester, _active());
    await openStory(tester);
    await tester.fling(
      find.text('حط سقف للصرف.').hitTestable().evaluate().isEmpty
          ? find.text('اكتب الناقص فعلاً.')
          : find.text('حط سقف للصرف.'),
      const Offset(0, -300),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(chat.sent, <String>['حطلي سقف صرف للعروض.']);
  });

  testWidgets('past the last slide it closes without asking', (tester) async {
    final (_, chat) = await pump(tester, _active());
    await openStory(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tapAt(const Offset(200, 400));
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpAndSettle(); // the route's fade out
    expect(find.text('استنى ٢٤ ساعة.'), findsNothing);
    expect(find.text('الوايت فرايداي'), findsOneWidget); // back on the strip
    expect(chat.sent, isEmpty);
    expect(box.get('story_seen'), 'wf@2026-11-20');
  });

  test(
    'slides without an emoji or a line are skipped, and survive the cache',
    () {
      final c = Campaign.fromJson(
        _row(
          slides: <Object?>[
            <String, String>{'emoji': '🛍️', 'text': 'تمام'},
            <String, String>{'emoji': '', 'text': 'من غير إيموجي'},
            <String, String>{'emoji': '📏'},
            'نص بس',
          ],
        ),
      )!;
      expect(c.slides, <StorySlide>[(emoji: '🛍️', text: 'تمام')]);
      expect(Campaign.fromJson(c.toJson())!.slides, c.slides);
    },
  );
}
