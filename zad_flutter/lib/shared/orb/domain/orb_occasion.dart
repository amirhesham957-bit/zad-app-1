/// What Zad's orb wears for an occasion — the pet plan's «لبس المناسبات»
/// (owner-approved 2026-10-11), first step: drawn by the orb's own painter,
/// keyed off the same campaign the Home banner shows, so the orb and the
/// banner never celebrate different things.
///
/// Every look sits where the family accessories (bow, glasses, flower,
/// crown) do not: a lantern or balloons held at the side, a scarf at the
/// neck. A customer's chosen accessory is never replaced by a season.
library;

import 'dart:ui';

import 'package:flutter/foundation.dart';

/// The kind of look.
enum OrbOccasionLook {
  /// Nothing for the season.
  none,

  /// A fanous held at the side, swaying with the breath — Ramadan.
  lantern,

  /// Three balloons on strings, bobbing — the two Eids.
  balloons,

  /// A scarf at the neck in the occasion's own colours — national days and
  /// the new year.
  scarf,
}

/// Which look an occasion (`app_campaigns.event_key`) gets. The keys are the
/// thirteen on the live table (2026-10-11). Commercial days (White Friday),
/// the plain seasons (autumn, back to school) and Halloween get nothing:
/// the orb dresses for a celebration, not for every banner.
OrbOccasionLook orbLookFor(String? eventKey) => switch (eventKey) {
  'ramadan' => OrbOccasionLook.lantern,
  'eid_al_fitr' || 'eid_al_adha' => OrbOccasionLook.balloons,
  'saudi_national_day' ||
  'saudi_founding_day' ||
  'egypt_october_6' ||
  'egypt_july_23' ||
  'uae_union_day' ||
  'new_year' => OrbOccasionLook.scarf,
  _ => OrbOccasionLook.none,
};

/// A look with the occasion's colours.
@immutable
class OrbOccasion {
  /// Creates one.
  const new(this.look, {this.primary, this.secondary});

  /// Nothing worn.
  static const OrbOccasion none = OrbOccasion(OrbOccasionLook.none);

  /// The kind.
  final OrbOccasionLook look;

  /// The occasion's first colour (`theme_primary`); the look's own when null.
  final Color? primary;

  /// Its second colour (`theme_secondary`).
  final Color? secondary;

  @override
  bool operator ==(Object other) =>
      other is OrbOccasion &&
      other.look == look &&
      other.primary == primary &&
      other.secondary == secondary;

  @override
  int get hashCode => Object.hash(look, primary, secondary);
}
