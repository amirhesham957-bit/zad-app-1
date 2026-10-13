/// The customer's one balance, «محاولات» — what `zad_entitlement_status`
/// reports since 20261012020000.
///
/// Logging is free and never counts. A chat message costs 1, a scan 2, a deep
/// analysis 3. The free tier gets 5 back every 5 hours, never stacking above
/// 5 — attempts earned from ads come on top and survive the refill
/// (20261012100000); the paid plans get 300, 1000 or 2500 a month.
library;

import 'package:flutter/foundation.dart';

/// What each kind of request costs — the server's `zad_attempt_cost`.
abstract final class AttemptCosts {
  /// A chat message.
  static const int chat = 1;

  /// A receipt or photo scan.
  static const int scan = 2;

  /// A deep analysis («حلل»، «توقع»، «خطة»).
  static const int brain = 3;
}

/// The balance at one moment.
@immutable
class AttemptsBalance {
  /// Creates a balance.
  const new({
    required this.tier,
    required this.left,
    required this.perCycle,
    required this.nextRefillAt,
    required this.adsEnabled,
    this.adLeft = 0,
  });

  /// Reads `zad_entitlement_status`'s answer, or null when it is not one (an
  /// `error` key, or a server that predates the one balance).
  static AttemptsBalance? fromStatus(Map<String, dynamic> json) {
    if (json.containsKey('error')) return null;
    final left = json['attempts_left'];
    if (left is! num) return null;
    final perCycle = json['attempts_per_cycle'];
    final next = json['next_refill_at'];
    final adLeft = json['ad_attempts_left'];
    return AttemptsBalance(
      tier: (json['tier'] as String?) ?? 'free',
      left: left.toInt(),
      perCycle: perCycle is num ? perCycle.toInt() : 5,
      nextRefillAt: next is String ? DateTime.tryParse(next) : null,
      adsEnabled: json['ads_enabled'] == true,
      adLeft: adLeft is num ? adLeft.toInt() : 0,
    );
  }

  /// `free`, `starter`, `plus` or `pro`.
  final String tier;

  /// Attempts left now.
  final int left;

  /// What a cycle gives: 5 for the free tier, the plan's monthly figure
  /// otherwise.
  final int perCycle;

  /// When the balance comes back to [perCycle].
  final DateTime? nextRefillAt;

  /// Whether this tier sees ads.
  final bool adsEnabled;

  /// How much of [left] was earned from ads. It stays through the refill, so
  /// the cycle's own attempts are [left] less this.
  final int adLeft;

  /// What is left of the cycle's own attempts — what the refill tops up.
  int get cycleLeft => left - adLeft.clamp(0, left);

  /// On the free tier.
  bool get isFree => tier == 'free';

  /// Low enough to say so: less than one deep analysis.
  bool get isLow => left < AttemptCosts.brain;

  /// The plan's name as the paywall says it.
  String get planName => switch (tier) {
    'starter' => 'الأساسية',
    'plus' => 'بلس',
    'pro' => 'العيلة',
    _ => 'المجانية',
  };

  @override
  bool operator ==(Object other) =>
      other is AttemptsBalance &&
      other.tier == tier &&
      other.left == left &&
      other.perCycle == perCycle &&
      other.nextRefillAt == nextRefillAt &&
      other.adsEnabled == adsEnabled &&
      other.adLeft == adLeft;

  @override
  int get hashCode =>
      Object.hash(tier, left, perCycle, nextRefillAt, adsEnabled, adLeft);
}

/// «محاولة واحدة»، «محاولتين»، «٣ محاولات»، «١١ محاولة» — the noun agrees with
/// the count, the same rule as the server's `attempts()`.
String attemptsLabel(int n) {
  final k = n < 0 ? 0 : n;
  if (k == 0) return 'ولا محاولة';
  if (k == 1) return 'محاولة واحدة';
  if (k == 2) return 'محاولتين';
  final digits = arabicDigits(k);
  return k <= 10 ? '$digits محاولات' : '$digits محاولة';
}

/// Western digits to Arabic-Indic, as the rest of the copy writes them.
String arabicDigits(int n) {
  const map = <String, String>{
    '0': '٠',
    '1': '١',
    '2': '٢',
    '3': '٣',
    '4': '٤',
    '5': '٥',
    '6': '٦',
    '7': '٧',
    '8': '٨',
    '9': '٩',
  };
  return n.toString().split('').map((c) => map[c] ?? c).join();
}
