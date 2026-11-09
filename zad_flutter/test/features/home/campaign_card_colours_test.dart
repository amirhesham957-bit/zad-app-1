// The balance card under an occasion: one colour, the second only as a light.
// Mixing the two turned a black and a brown into mud (White Friday).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/features/home/presentation/campaign_banner.dart';
import 'package:zad/shared/campaigns/domain/campaign.dart';

ActiveCampaign _occasion(String secondary) => ActiveCampaign(
  campaign: Campaign.fromJson(<String, dynamic>{
    'id': 'wf',
    'event_key': 'white_friday',
    'from_md': '11-20',
    'to_md': '11-30',
    'theme_primary': '#111827',
    'theme_secondary': secondary,
    'badge': '🛍️',
    'banner_title': 't',
    'banner_body': 'b',
    'cta_text': 'c',
    'cta_prompt': 'p',
  })!,
  start: DateTime.utc(2026, 11, 20),
  end: DateTime.utc(2026, 11, 30),
);

void main() {
  test('the panel never runs through the second colour', () {
    final colours = campaignCardGradient(_occasion('#854D0E'))!.colors;
    expect(colours.first, const Color(0xFF111827));
    expect(colours, isNot(contains(const Color(0xFF854D0E))));
  });

  test('the second colour is a faint light, not a fill', () {
    final glow = campaignCardGlow(_occasion('#854D0E'))!;
    expect(glow.a, lessThanOrEqualTo(0.5));
    expect(
      HSLColor.fromColor(glow).hue,
      closeTo(HSLColor.fromColor(const Color(0xFF854D0E)).hue, 1),
    );
  });

  test('colours white text cannot read on fall back to زاد own', () {
    expect(campaignCardGradient(_occasion('#FDE68A')), isNull);
    expect(campaignCardGlow(_occasion('#FDE68A')), isNull);
    expect(campaignCardGradient(null), isNull);
  });
}
