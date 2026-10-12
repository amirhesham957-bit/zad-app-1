// The app's copy of the wardrobe (companion_offers.dart) against the
// migration that seeds zad_companion_items: same ids, kinds, unlocks, prices.
// A price or an unlock changed on one side only would show the customer one
// thing and charge another.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zad/shared/companion/domain/companion_catalog.dart';
import 'package:zad/shared/companion/domain/companion_offers.dart';

void main() {
  final sql = File('../supabase/migrations/20261012030000_companion.sql')
      .readAsStringSync();
  final row = RegExp(
    r"\('(\w+)',\s*'(\w+)',\s*'[^']*',\s*'(\w+)',\s*(\w+),\s*('?\w+'?),\s*(\w+),\s*('?\w+'?),\s*([\d.]+|null),\s*\d+\)",
  );
  final server = <String, List<String>>{
    for (final m in row.allMatches(sql))
      m.group(1)!: <String>[
        m.group(2)!,
        m.group(3)!,
        m.group(4)!,
        m.group(5)!.replaceAll("'", ''),
        m.group(6)!,
        m.group(8)!,
      ],
  };

  test('the migration seeds 19 items', () {
    expect(server, hasLength(19));
  });

  test('every offer matches its row in zad_companion_items', () {
    expect(companionOffers.map((o) => o.id).toSet(), server.keys.toSet());
    for (final o in companionOffers) {
      final r = server[o.id]!;
      expect(r[0], o.kind.name, reason: '${o.id} kind');
      expect(r[1], o.unlock.name, reason: '${o.id} unlock');
      expect(
        r[2],
        o.unlockValue?.toString() ?? 'null',
        reason: '${o.id} unlock value',
      );
      expect(r[3], o.season ?? 'null', reason: '${o.id} season');
      expect(r[4], o.seedPrice?.toString() ?? 'null', reason: '${o.id} seeds');
      expect(r[5], o.usdPrice?.toString() ?? 'null', reason: '${o.id} usd');
    }
  });

  test('every offer is something the orb can draw', () {
    for (final o in companionOffers) {
      switch (o.kind) {
        case OfferKind.persona:
          expect(CompanionPersona.byId(o.id).id, o.id);
        case OfferKind.outfit:
          expect(CompanionOutfit.byId(o.id).id, o.id);
        case OfferKind.background:
          expect(CompanionBackground.byId(o.id).id, o.id);
      }
    }
  });
}
