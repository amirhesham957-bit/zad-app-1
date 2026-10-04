// The seasonal banner on home (app_campaigns): today's campaign for where the
// phone is and how the customer speaks, in the account's civil date; one
// button that asks زاد, only when tapped; dismissed until next time.
//
// Everything that touches the disk happens in setUp — a Hive write inside a
// testWidgets body never completes under the faked clock.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/home/application/home_campaign.dart';
import 'package:zad/features/home/presentation/campaign_banner.dart';
import 'package:zad/features/home/presentation/travel_banner.dart';
import 'package:zad/shared/brain/application/memory_controller.dart';
import 'package:zad/shared/brain/data/memory_repository.dart';
import 'package:zad/shared/brain/domain/customer_profile.dart';
import 'package:zad/shared/campaigns/application/campaigns_controller.dart';
import 'package:zad/shared/campaigns/domain/campaign.dart';
import 'package:zad/shared/chat/application/chat_controller.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/shell_navigation.dart';

import '../../support/quiet_household.dart';

Map<String, dynamic> _row(
  String id, {
  String? country,
  String? dialect,
  String from = '10-25',
  String to = '10-31',
  String title = 'هالوين',
  String secondary = '#9A3412',
  int priority = 0,
}) => <String, dynamic>{
  'id': id,
  'event_key': id,
  'target_country': country,
  'dialect': dialect,
  'from_md': from,
  'to_md': to,
  'theme_primary': '#4C1D95',
  'theme_secondary': secondary,
  'badge': '🎃',
  'particles': 'confetti',
  'banner_title': title,
  'banner_body': 'زاد يطلّعلك المصاريف المخيفة.',
  'cta_text': 'اكشفلي المصاريف',
  'cta_prompt': 'طلّعلي أكتر ٣ مصاريف بتاكل ميزانيتي.',
  'priority': priority,
};

final CampaignCatalog _catalog = CampaignCatalog.fromRows(
  campaigns: <Map<String, dynamic>>[
    _row('halloween'),
    _row('halloween_gulf', dialect: 'GULF', title: 'هالوين خليجي'),
    _row('saudi', country: 'SA', from: '10-01', title: 'سعودي', priority: 10),
  ],
  seasons: const <Map<String, dynamic>>[],
);

class _Catalog extends CampaignsController {
  @override
  CampaignCatalog build() => _catalog;
}

class _Memory extends MemoryController {
  new(this.dialect);

  final String? dialect;

  @override
  MemoryView build() => MemoryView(
    snapshot: MemorySnapshot(profile: CustomerProfile(dialect: dialect)),
  );

  @override
  Future<void> refresh() async {}
}

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
  late Box<String> documents;
  late Box<String> device;
  var run = 0;

  setUpAll(tz_data.initializeTimeZones);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_campaign_banner');
    Hive.init(dir.path);
    documents = await Hive.openBox<String>('documents${run++}');
    device = await Hive.openBox<String>('device$run');
    // The account's market, for a phone with no mobile network.
    await documents.put(
      'account_settings',
      jsonEncode(<String, dynamic>{'country': 'EG'}),
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  ZadLocalStore store() => ZadLocalStore(
    outbox: documents,
    transactions: documents,
    documents: documents,
    chat: documents,
    inventory: documents,
    shopping: documents,
    pharmacy: documents,
    subscriptions: documents,
    device: device,
  );

  ProviderContainer container({
    required String now,
    String zone = 'Asia/Riyadh',
    String? network,
    String? dialect,
  }) {
    final c = ProviderContainer(
      overrides: [
        ...quietHouseholdOverrides,
        localStoreProvider.overrideWithValue(store()),
        campaignsControllerProvider.overrideWith(_Catalog.new),
        memoryControllerProvider.overrideWith(() => _Memory(dialect)),
        accountTimeZoneProvider.overrideWithValue(zone),
        networkCountryProvider.overrideWith((ref) async => network),
        nowProvider.overrideWithValue(() => DateTime.parse(now)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<String?> pick(ProviderContainer c) async {
    await c.read(networkCountryProvider.future);
    return c.read(homeCampaignProvider)?.campaign.id;
  }

  group('which campaign', () {
    test("today is the account's date, not the device's", () async {
      // 21:30 UTC on the 24th is already the 25th in Riyadh.
      expect(await pick(container(now: '2026-10-24T21:30:00Z')), 'halloween');
      expect(
        await pick(container(now: '2026-10-24T21:30:00Z', zone: 'UTC')),
        isNull,
      );
    });

    test('the mobile network places the customer before the market', () async {
      expect(
        await pick(container(now: '2026-10-28T12:00:00Z', network: 'SA')),
        'saudi',
      );
    });

    test('without a mobile network, the account market', () async {
      // The market is EG: the Saudi campaign is not theirs.
      expect(await pick(container(now: '2026-10-28T12:00:00Z')), 'halloween');
    });

    test('the dialect chosen in «ملفي» picks the copy', () async {
      expect(
        await pick(container(now: '2026-10-28T12:00:00Z', dialect: 'GULF')),
        'halloween_gulf',
      );
    });

    test('nothing outside every window', () async {
      expect(await pick(container(now: '2026-06-15T12:00:00Z')), isNull);
    });
  });

  group('the banner', () {
    final active = pickCampaign(_catalog, today: DateTime.utc(2026, 10, 28))!;

    Future<(ProviderContainer, _Chat)> pumpSlot(
      WidgetTester tester, {
      bool still = true,
      ActiveCampaign? campaign,
    }) async {
      final chat = _Chat();
      final c = ProviderContainer(
        overrides: [
          ...quietHouseholdOverrides,
          localStoreProvider.overrideWithValue(store()),
          homeCampaignProvider.overrideWithValue(campaign ?? active),
          chatControllerProvider.overrideWith(() => chat),
        ],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: ZadTheme.light(),
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: still),
              child: const Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(body: CampaignBannerSlot()),
              ),
            ),
          ),
        ),
      );
      return (c, chat);
    }

    testWidgets('shows the occasion, and asks nothing on open', (tester) async {
      final (_, chat) = await pumpSlot(tester);
      await tester.pumpAndSettle();
      expect(find.text('هالوين'), findsOneWidget);
      expect(find.text('زاد يطلّعلك المصاريف المخيفة.'), findsOneWidget);
      expect(find.text('🎃'), findsOneWidget);
      expect(find.text('اكشفلي المصاريف'), findsOneWidget);
      expect(chat.sent, isEmpty);
    });

    testWidgets('the button asks زاد and opens the chat', (tester) async {
      final (c, chat) = await pumpSlot(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('اكشفلي المصاريف'));
      await tester.pump();
      expect(chat.sent, <String>['طلّعلي أكتر ٣ مصاريف بتاكل ميزانيتي.']);
      expect(c.read(shellNavigationProvider), ShellTab.chat);
    });

    testWidgets('the close mark hides it', (tester) async {
      await pumpSlot(tester);
      await tester.pumpAndSettle();
      // The dismissal is written to the device box: real time, or the write
      // never completes under the faked clock.
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('إخفاء'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(find.text('هالوين'), findsNothing);
      expect(device.get('dismissed_campaign'), active.key);
    });

    testWidgets('the button and the close mark are thumb-sized', (
      tester,
    ) async {
      await pumpSlot(tester);
      await tester.pumpAndSettle();
      final button = tester.getSize(find.byType(FilledButton));
      final close = tester.getSize(find.byTooltip('إخفاء'));
      expect(button.height, greaterThanOrEqualTo(44));
      expect(close.height, greaterThanOrEqualTo(44));
      expect(close.width, greaterThanOrEqualTo(44));
    });

    testWidgets('confetti falls without errors when motion is allowed', (
      tester,
    ) async {
      await pumpSlot(tester, still: false);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 6));
      expect(tester.takeException(), isNull);
      expect(find.text('هالوين'), findsOneWidget);
      // Unmount before the end: the loop never settles on its own.
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('dismissed earlier', () {
    final active = pickCampaign(_catalog, today: DateTime.utc(2026, 10, 28))!;

    setUp(() async {
      await device.put('dismissed_campaign', active.key);
    });

    testWidgets('stays hidden for the rest of the occasion', (tester) async {
      final c = ProviderContainer(
        overrides: [
          ...quietHouseholdOverrides,
          localStoreProvider.overrideWithValue(store()),
          homeCampaignProvider.overrideWithValue(active),
        ],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: Scaffold(body: CampaignBannerSlot())),
        ),
      );
      expect(find.text('هالوين'), findsNothing);
    });

    testWidgets('and comes back next year', (tester) async {
      final nextYear = pickCampaign(
        _catalog,
        today: DateTime.utc(2027, 10, 28),
      )!;
      final c = ProviderContainer(
        overrides: [
          ...quietHouseholdOverrides,
          localStoreProvider.overrideWithValue(store()),
          homeCampaignProvider.overrideWithValue(nextYear),
        ],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: Scaffold(body: CampaignBannerSlot()),
            ),
          ),
        ),
      );
      expect(find.text('هالوين'), findsOneWidget);
    });
  });

  test('colours that would hide white text fall back to زاد green', () {
    final pale = pickCampaign(
      CampaignCatalog.fromRows(
        campaigns: <Map<String, dynamic>>[_row('p', secondary: '#FDE68A')],
        seasons: const <Map<String, dynamic>>[],
      ),
      today: DateTime.utc(2026, 10, 28),
    );
    expect(campaignGradient(pale), isNull);
    expect(campaignGradient(null), isNull);
    expect(
      campaignGradient(
        pickCampaign(_catalog, today: DateTime.utc(2026, 10, 28)),
      ),
      isNotNull,
    );
  });
}
