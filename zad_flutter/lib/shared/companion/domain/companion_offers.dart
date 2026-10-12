/// How each wardrobe item opens — the app's copy of `zad_companion_items`
/// (migration 20261012030000), so the studio can say «لفل ١٠» or «٣٠٠ 🌱»
/// without a second round trip. The server still decides every unlock and
/// every sale; `companion_offers_test.dart` reads the migration and fails if
/// this list and it ever disagree.
library;

import 'package:flutter/foundation.dart';

/// The kinds of thing in the wardrobe.
enum OfferKind {
  /// A character.
  persona,

  /// Something worn.
  outfit,

  /// The studio's background.
  background,
}

/// How an item opens without paying money.
enum OfferUnlock {
  /// Owned from the first day.
  free,

  /// At a level.
  level,

  /// When this many friends have joined and started.
  invite,

  /// With a Plus (or any paid) plan.
  plus,

  /// Only in its season.
  season,

  /// Only with seeds (or money).
  seeds,
}

/// One item and how it opens.
@immutable
class CompanionOffer {
  /// Creates one.
  const new(
    this.id,
    this.kind,
    this.name,
    this.unlock, {
    this.unlockValue,
    this.season,
    this.seedPrice,
    this.usdPrice,
  });

  /// The server's id.
  final String id;

  /// Character, outfit or background.
  final OfferKind kind;

  /// Its Arabic name.
  final String name;

  /// How it opens.
  final OfferUnlock unlock;

  /// The level, or the number of friends.
  final int? unlockValue;

  /// `ramadan` or `eid`.
  final String? season;

  /// Its price in seeds, when seeds can buy it.
  final int? seedPrice;

  /// Its price on Google Play, in US dollars.
  final double? usdPrice;

  /// What opens it, said plainly; null for a free item.
  String? get howToOpen => switch (unlock) {
    OfferUnlock.free => null,
    OfferUnlock.level => 'يتفتح عند لفل ${unlockValue ?? 0}',
    OfferUnlock.invite =>
      (unlockValue ?? 1) == 1
          ? 'يتفتح لما صاحب يسجّل'
          : 'يتفتح لما $unlockValue صحاب يسجّلوا',
    OfferUnlock.plus => 'هدية مع اشتراك بلس',
    OfferUnlock.season => season == 'ramadan' ? 'في رمضان بس' : 'في العيد بس',
    OfferUnlock.seeds => null,
  };
}

/// Everything in the wardrobe, in the studio's order.
const List<CompanionOffer> companionOffers = <CompanionOffer>[
  CompanionOffer('zado', OfferKind.persona, 'زادو', OfferUnlock.free),
  CompanionOffer(
    'basbous',
    OfferKind.persona,
    'بسبوس',
    OfferUnlock.level,
    unlockValue: 10,
    seedPrice: 1500,
    usdPrice: 1.99,
  ),
  CompanionOffer(
    'fella',
    OfferKind.persona,
    'فلة',
    OfferUnlock.invite,
    unlockValue: 1,
    seedPrice: 1500,
    usdPrice: 1.99,
  ),
  CompanionOffer(
    'felfool',
    OfferKind.persona,
    'فلفول',
    OfferUnlock.seeds,
    seedPrice: 2000,
    usdPrice: 1.99,
  ),
  CompanionOffer(
    'mishmish',
    OfferKind.persona,
    'مشمش',
    OfferUnlock.seeds,
    seedPrice: 2000,
    usdPrice: 1.99,
  ),
  CompanionOffer(
    'toota',
    OfferKind.persona,
    'توتة',
    OfferUnlock.plus,
    seedPrice: 3000,
    usdPrice: 2.99,
  ),
  CompanionOffer(
    'fanoos',
    OfferKind.persona,
    'فانوس',
    OfferUnlock.season,
    season: 'ramadan',
    seedPrice: 2500,
    usdPrice: 2.99,
  ),
  CompanionOffer(
    'maamoul',
    OfferKind.persona,
    'معمول',
    OfferUnlock.season,
    season: 'eid',
    seedPrice: 2500,
    usdPrice: 2.99,
  ),
  CompanionOffer(
    'sunglasses',
    OfferKind.outfit,
    'نضارة شمس',
    OfferUnlock.seeds,
    seedPrice: 300,
    usdPrice: 0.99,
  ),
  CompanionOffer(
    'winter_hat',
    OfferKind.outfit,
    'طاقية شتوي',
    OfferUnlock.seeds,
    seedPrice: 400,
    usdPrice: 0.99,
  ),
  CompanionOffer(
    'chef_hat',
    OfferKind.outfit,
    'طاقية الشيف',
    OfferUnlock.level,
    unlockValue: 15,
    seedPrice: 450,
    usdPrice: 0.99,
  ),
  CompanionOffer(
    'shemagh',
    OfferKind.outfit,
    'شماغ',
    OfferUnlock.seeds,
    seedPrice: 500,
    usdPrice: 0.99,
  ),
  CompanionOffer(
    'grad_cap',
    OfferKind.outfit,
    'طاقية التخرج',
    OfferUnlock.invite,
    unlockValue: 3,
    seedPrice: 600,
    usdPrice: 0.99,
  ),
  CompanionOffer('morning', OfferKind.background, 'الصبح', OfferUnlock.free),
  CompanionOffer(
    'night',
    OfferKind.background,
    'بالليل',
    OfferUnlock.seeds,
    seedPrice: 200,
    usdPrice: 0.49,
  ),
  CompanionOffer(
    'garden',
    OfferKind.background,
    'الجنينة',
    OfferUnlock.level,
    unlockValue: 5,
    seedPrice: 300,
    usdPrice: 0.49,
  ),
  CompanionOffer(
    'kitchen',
    OfferKind.background,
    'المطبخ',
    OfferUnlock.seeds,
    seedPrice: 350,
    usdPrice: 0.49,
  ),
  CompanionOffer(
    'stars',
    OfferKind.background,
    'سما النجوم',
    OfferUnlock.level,
    unlockValue: 25,
    seedPrice: 500,
    usdPrice: 0.99,
  ),
  CompanionOffer(
    'shilla',
    OfferKind.background,
    'الشلة',
    OfferUnlock.invite,
    unlockValue: 3,
    seedPrice: 500,
    usdPrice: 0.99,
  ),
];
