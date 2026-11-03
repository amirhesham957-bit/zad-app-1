import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zad/core/l10n/generated/zad_l10n.dart';
import 'package:zad/shared/companion/domain/companion_catalog.dart';
import 'package:zad/shared/companion/domain/companion_offers.dart';
import 'package:zad/shared/companion/domain/fourth_wall.dart';
import 'package:zad/shared/companion/domain/pet_care.dart';
import 'package:zad/shared/companion/domain/pet_stories.dart';
import 'package:zad/shared/companion/domain/price_games.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';

final RegExp _arabic = RegExp('[؀-ۿ]');

void main() {
  final ar = lookupZadL10n(const Locale('ar'));
  final en = lookupZadL10n(const Locale('en'));

  // A select falls to `other` silently, so a misspelt arm would show the
  // wrong name with a green build: every value must get its own text.
  test('every character, stage, outfit and background has its own words', () {
    for (final l in <ZadL10n>[ar, en]) {
      final traits = CompanionPersona.values.map((p) => p.trait(l)).toSet();
      final lines = CompanionPersona.values.map((p) => p.line(l)).toSet();
      expect(traits, hasLength(CompanionPersona.values.length));
      expect(lines, hasLength(CompanionPersona.values.length));
      final stages = CompanionStage.values.map((s) => s.label(l)).toSet();
      final told = CompanionStage.values.map((s) => s.description(l)).toSet();
      expect(stages, hasLength(CompanionStage.values.length));
      expect(told, hasLength(CompanionStage.values.length));
      final worn = CompanionOutfit.values.map((o) => o.label(l)).toSet();
      expect(worn, hasLength(CompanionOutfit.values.length));
      expect(CompanionOutfit.none.label(l), isEmpty);
      final bgs = CompanionBackground.values.map((b) => b.label(l)).toSet();
      expect(bgs, hasLength(CompanionBackground.values.length));
      expect(
        PriceSource.values.map((s) => s.label(l)).toSet(),
        hasLength(PriceSource.values.length),
      );
    }
  });

  test('Arabic by default, the catalog unchanged', () {
    expect(CompanionStage.sage.label(), 'حكيم');
    expect(CompanionOutfit.chefHat.label(), 'طاقية الشيف');
    expect(CompanionBackground.stars.label(), 'سما النجوم');
    expect(CompanionPersona.basbous.displayName(), 'بسبوس');
    expect(CompanionPersona.basbous.displayName(ar), 'بسبوس');
  });

  test('in English: the Latin name, and no Arabic in any line', () {
    expect(CompanionPersona.basbous.displayName(en), 'Basbous');
    for (final o in companionOffers) {
      expect(o.label(en), isNot(matches(_arabic)), reason: o.id);
      expect(o.howToOpen(en) ?? '', isNot(matches(_arabic)), reason: o.id);
    }
    expect(companionOffers[1].howToOpen(en), 'Opens at level 10');
    final lines = <String?>[
      for (var i = 0; i < 4; i++) ...<String?>[
        FourthWall.poked(6, name: 'Zado', rng: math.Random(i), l10n: en),
        FourthWall.poked(9, name: 'Zado', rng: math.Random(i), l10n: en),
        FourthWall.back(
          const Duration(hours: 7),
          rng: math.Random(i),
          l10n: en,
        ),
        FourthWall.clock(2, rng: math.Random(i), l10n: en),
        FourthWall.paywall(name: 'Zado', rng: math.Random(i), l10n: en),
        for (final m in CompanionState.values)
          PetLines.forMood(
            m,
            name: 'Zado',
            loggedToday: i.isEven,
            rng: math.Random(i),
            l10n: en,
          ),
        PetLines.fed(PetCareOutcome.full, rng: math.Random(i), l10n: en),
        PetLines.petted(rng: math.Random(i), l10n: en),
        PetStories.weekly(
          days: i,
          goal: 3,
          stage: CompanionStage.sage,
          l10n: en,
        ),
      ],
    ];
    for (final line in lines.whereType<String>()) {
      expect(line, isNot(matches(_arabic)), reason: line);
    }
    expect(FourthWall.poked(12, name: 'Zado', l10n: en), contains('12'));
  });
}
