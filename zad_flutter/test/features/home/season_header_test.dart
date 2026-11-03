// ZAD_PLAN 8b.4: the occasion's colours and particles in the shared header,
// so a winter week shows on every screen — and nothing on a plain day.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/home/application/home_campaign.dart';
import 'package:zad/features/home/presentation/campaign_banner.dart';
import 'package:zad/features/home/presentation/season_header.dart';
import 'package:zad/shared/campaigns/domain/campaign.dart';

ActiveCampaign _winter() => ActiveCampaign(
  campaign: Campaign.fromJson(<String, dynamic>{
    'id': 'w',
    'event_key': 'winter',
    'from_md': '11-01',
    'to_md': '02-28',
    'theme_primary': '#0C4A6E',
    'theme_secondary': '#1E3A8A',
    'badge': '❄️',
    'particles': 'snow',
    'banner_title': 'شتا',
    'banner_body': 'b',
    'cta_text': 'c',
    'cta_prompt': 'p',
    'priority': -10,
  })!,
  start: DateTime.utc(2026, 11),
  end: DateTime.utc(2027, 2, 28),
  intensity: CampaignIntensity.low,
);

Widget _host(ActiveCampaign? active, {bool still = false}) => ProviderScope(
  overrides: [homeCampaignProvider.overrideWithValue(active)],
  child: MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: still),
      child: const SizedBox(
        width: 400,
        height: 120,
        child: SeasonHeaderLayer(),
      ),
    ),
  ),
);

void main() {
  testWidgets('a plain day draws nothing', (tester) async {
    await tester.pumpWidget(_host(null));
    expect(find.byType(CampaignParticlesLayer), findsNothing);
  });

  testWidgets('winter: the wash and sparse snow, behind the controls', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_winter()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey<String>('season-header-winter')),
      findsOne,
    );
    final layer = tester.widget<CampaignParticlesLayer>(
      find.byType(CampaignParticlesLayer),
    );
    expect(layer.kind, CampaignParticles.snow);
    expect(layer.intensity, CampaignIntensity.low);
    expect(layer.ink, isNotNull);
    expect(find.byType(IgnorePointer), findsWidgets);
  });

  testWidgets('remove-animations freezes the particles', (tester) async {
    await tester.pumpWidget(_host(_winter(), still: true));
    final layer = tester.widget<CampaignParticlesLayer>(
      find.byType(CampaignParticlesLayer),
    );
    expect(layer.still, isTrue);
  });
}
