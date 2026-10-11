// The orb dresses for the occasion the Home banner shows: a lantern in
// Ramadan, balloons on the Eids, a scarf in the day's colours on national
// days — and nothing for a sale or a plain season.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/campaigns/application/market_season.dart';
import 'package:zad/shared/campaigns/domain/campaign.dart';
import 'package:zad/shared/orb/application/orb_accessory_controller.dart';
import 'package:zad/shared/orb/application/orb_occasion_controller.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/orb/domain/orb_accessory.dart';
import 'package:zad/shared/orb/domain/orb_occasion.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';

ActiveCampaign _season(String key, {bool bridged = false}) => ActiveCampaign(
  campaign: Campaign.fromJson(<String, dynamic>{
    'id': key,
    'event_key': key,
    'event_name': key,
    'from_md': '10-01',
    'to_md': '10-31',
    'theme_primary': '#006C35',
    'theme_secondary': '#FFFFFF',
    'banner_title': 't',
    'banner_body': 'b',
    'cta_text': 'c',
    'cta_prompt': 'p',
  })!,
  start: DateTime.utc(2026, 10),
  end: DateTime.utc(2026, 10, 31),
  bridged: bridged,
);

OrbOccasion _read(ActiveCampaign? Function() season) {
  final container = ProviderContainer(
    overrides: [marketSeasonProvider.overrideWith((ref) => season())],
  );
  addTearDown(container.dispose);
  return container.read(orbOccasionProvider);
}

void main() {
  test('every occasion on the live table gets the look meant for it', () {
    // app_campaigns.event_key, all thirteen, 2026-10-11.
    const expected = <String, OrbOccasionLook>{
      'ramadan': OrbOccasionLook.lantern,
      'eid_al_fitr': OrbOccasionLook.balloons,
      'eid_al_adha': OrbOccasionLook.balloons,
      'saudi_national_day': OrbOccasionLook.scarf,
      'saudi_founding_day': OrbOccasionLook.scarf,
      'egypt_october_6': OrbOccasionLook.scarf,
      'egypt_july_23': OrbOccasionLook.scarf,
      'uae_union_day': OrbOccasionLook.scarf,
      'new_year': OrbOccasionLook.scarf,
      'white_friday': OrbOccasionLook.none,
      'halloween': OrbOccasionLook.none,
      'autumn': OrbOccasionLook.none,
      'back_to_school': OrbOccasionLook.none,
    };
    for (final MapEntry(:key, :value) in expected.entries) {
      expect(orbLookFor(key), value, reason: key);
    }
    expect(orbLookFor(null), OrbOccasionLook.none);
    expect(orbLookFor('some_new_day'), OrbOccasionLook.none);
  });

  test("today's occasion is worn in its own colours", () {
    final look = _read(() => _season('saudi_national_day'));
    expect(look.look, OrbOccasionLook.scarf);
    expect(look.primary, const Color(0xFF006C35));
    expect(look.secondary, const Color(0xFFFFFFFF));
  });

  test('no occasion, one shown a week early, or one that cannot be read: '
      'nothing worn', () {
    expect(_read(() => null), OrbOccasion.none);
    expect(_read(() => _season('ramadan', bridged: true)), OrbOccasion.none);
    expect(_read(() => _season('white_friday')), OrbOccasion.none);
    expect(_read(() => throw StateError('no catalog')), OrbOccasion.none);
  });

  group('the orb draws it', () {
    Future<RenderBox> pump(
      WidgetTester tester,
      OrbOccasion occasion, {
      CompanionState state = CompanionState.idle,
      bool animated = true,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [orbAccessoryProvider.overrideWith(_NoAccessory.new)],
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Center(
              child: CompanionOrb(
                occasion: occasion,
                state: state,
                animated: animated,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      return tester.renderObject<RenderBox>(
        find.descendant(
          of: find.byType(CompanionOrb),
          matching: find.byType(CustomPaint),
        ),
      );
    }

    testWidgets('the scarf is in the occasion colours', (tester) async {
      final box = await pump(
        tester,
        const OrbOccasion(
          OrbOccasionLook.scarf,
          primary: Color(0xFF006C35),
          secondary: Color(0xFFFFFFFF),
        ),
      );
      expect(
        box,
        paints
          ..something(_drew(#drawPath, const Color(0xFF006C35)))
          ..something(_drew(#drawPath, const Color(0xFFFFFFFF))),
      );
    });

    testWidgets('the lantern glows', (tester) async {
      final box = await pump(
        tester,
        const OrbOccasion(OrbOccasionLook.lantern),
      );
      expect(box, paints..something(_drew(#drawCircle, _glow)));
    });

    testWidgets('the balloons take the occasion colours', (tester) async {
      final box = await pump(
        tester,
        const OrbOccasion(
          OrbOccasionLook.balloons,
          primary: Color(0xFF1B5E20),
          secondary: Color(0xFFFFD54F),
        ),
      );
      expect(
        box,
        paints
          ..something(_drew(#drawPath, const Color(0xFF1B5E20)))
          ..something(_drew(#drawPath, const Color(0xFFFFD54F))),
      );
    });

    testWidgets('without an occasion none of it is drawn', (tester) async {
      final box = await pump(tester, OrbOccasion.none);
      expect(box, isNot(paints..something(_drew(#drawCircle, _glow))));
    });

    testWidgets('every look in every mood, moving and still, draws', (
      tester,
    ) async {
      for (final look in OrbOccasionLook.values) {
        for (final state in CompanionState.values) {
          for (final animated in <bool>[true, false]) {
            await pump(
              tester,
              OrbOccasion(look),
              state: state,
              animated: animated,
            );
            expect(tester.takeException(), isNull, reason: '$look $state');
          }
        }
      }
    });
  });
}

/// The lantern's glow, `_lanternGlow` in the painter.
const Color _glow = Color(0x80FFB300);

/// A draw call of [method] with a paint of [color].
PaintPatternPredicate _drew(Symbol method, Color color) =>
    (m, args) =>
        m == method &&
        args.whereType<Paint>().any(
          (p) => p.color.toARGB32() == color.toARGB32(),
        );

class _NoAccessory extends OrbAccessoryController {
  @override
  OrbAccessory build() => OrbAccessory.none;
}
