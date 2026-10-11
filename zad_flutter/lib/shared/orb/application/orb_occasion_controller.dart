/// Today's occasion look for every orb in the app.
library;

import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/shared/campaigns/application/market_season.dart';
import 'package:zad/shared/campaigns/domain/campaign.dart';
import 'package:zad/shared/orb/domain/orb_occasion.dart';

/// What the orb wears today: the occasion running in the account's market
/// (not one bridged early — the orb dresses on the day, not the week
/// before), or nothing.
final orbOccasionProvider = Provider<OrbOccasion>((ref) {
  final ActiveCampaign? season;
  try {
    season = ref.watch(marketSeasonProvider);
  } on Object {
    // The orb is drawn everywhere, signed out and in tests too; a season it
    // cannot read is no season.
    return OrbOccasion.none;
  }
  if (season == null || season.bridged) return OrbOccasion.none;
  final look = orbLookFor(season.campaign.eventKey);
  if (look == OrbOccasionLook.none) return OrbOccasion.none;
  return OrbOccasion(
    look,
    primary: Color(season.campaign.primary),
    secondary: Color(season.campaign.secondary),
  );
});
