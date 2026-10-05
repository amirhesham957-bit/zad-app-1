// Seasonal family challenges (migration 20261005110000): while an occasion
// runs, the challenges card offers its challenge — titled, badged, ending
// with it — and a finished one shows its badge.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/core/data/local/boxes.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/zad_theme.dart';
import 'package:zad/features/savings/presentation/family_savings_screen.dart';
import 'package:zad/shared/campaigns/application/market_season.dart';
import 'package:zad/shared/campaigns/domain/campaign.dart';
import 'package:zad/shared/family/application/family_controller.dart';
import 'package:zad/shared/family/data/family_repository.dart';
import 'package:zad/shared/family/data/seasonal_badges.dart';
import 'package:zad/shared/family/domain/family.dart';

import '../../support/quiet_household.dart';

class _InFamily extends FamilyController {
  @override
  FamilyView build() => const FamilyView(
    status: InFamily(
      Family(id: 'f1', inviteCode: 'X', members: <FamilyMember>[]),
    ),
    userId: 'u1',
  );

  @override
  Future<void> refresh() async {}
}

final ActiveCampaign _halloween = ActiveCampaign(
  campaign: Campaign.fromJson(<String, dynamic>{
    'id': 'h',
    'event_key': 'halloween',
    'event_name': 'الهالوين',
    'from_md': '10-25',
    'to_md': '10-31',
    'theme_primary': '#4C1D95',
    'theme_secondary': '#9A3412',
    'badge': '🎃',
    'banner_title': 't',
    'banner_body': 'b',
    'cta_text': 'c',
    'cta_prompt': 'p',
  })!,
  start: DateTime.utc(2026, 10, 25),
  end: DateTime.utc(2026, 10, 31),
);

void main() {
  late Directory dir;
  late Box<String> box;
  var run = 0;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zad_seasonal_challenge');
    Hive.init(dir.path);
    box = await Hive.openBox<String>('b${run++}');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester, ActiveCampaign? season) async {
    final c = ProviderContainer(
      overrides: [
        supabaseClientProvider.overrideWithValue(quietSupabase),
        familyControllerProvider.overrideWith(_InFamily.new),
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
        marketSeasonProvider.overrideWithValue(season),
        nowProvider.overrideWithValue(() => DateTime.utc(2026, 10, 28, 12)),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: ZadTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SingleChildScrollView(child: FinancialChallengesCard()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets("offers the occasion's challenge while it runs", (tester) async {
    await pump(tester, _halloween);
    expect(find.textContaining('تحدي الهالوين'), findsOneWidget);
    expect(find.text('ابدأه'), findsOneWidget);
  });

  testWidgets('no occasion, no offer', (tester) async {
    await pump(tester, null);
    expect(find.text('ابدأه'), findsNothing);
  });

  testWidgets(
    'the challenge is titled and badged, and ends with the occasion',
    (tester) async {
      await pump(tester, _halloween);
      await tester.tap(find.text('ابدأه'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('تحدي الهالوين 🎃'), findsOneWidget);
      // The 28th to the 31st, both counted.
      expect(find.text('4'), findsOneWidget);
    },
  );

  test('a badge is earned only by a finished challenge that carries one', () {
    final badges = seasonalBadgesFrom(<Map<String, dynamic>>[
      <String, dynamic>{
        'is_completed': true,
        'completed_at': '2026-03-01T10:00:00Z',
        'family_financial_challenges': <String, dynamic>{
          'title': 'تحدي رمضان 🌙',
          'badge': '🌙',
        },
      },
      <String, dynamic>{
        'is_completed': true,
        'completed_at': '2026-11-01T10:00:00Z',
        'family_financial_challenges': <String, dynamic>{
          'title': 'تحدي الهالوين',
          'badge': '🎃',
        },
      },
      <String, dynamic>{
        'is_completed': false,
        'family_financial_challenges': <String, dynamic>{
          'title': 'لسه',
          'badge': '🎆',
        },
      },
      <String, dynamic>{
        'is_completed': true,
        'family_financial_challenges': <String, dynamic>{
          'title': 'عادي',
          'badge': null,
        },
      },
    ]);
    expect(badges.map((b) => b.badge), <String>['🎃', '🌙']);
  });
}
