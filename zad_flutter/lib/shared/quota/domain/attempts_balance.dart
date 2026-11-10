/// The customer's one balance, «محاولات» — what `zad_entitlement_status`
/// reports since 20261012020000.
///
/// Logging is free and never counts. A chat message costs 1, a deep analysis
/// 3. The free tier gets 20 messages, 3 voice questions and 2 images back
/// every 2 hours, each kind on its own (20261110210000) — what ads earned
/// comes on top and survives the refill; the paid plans get 300, 1000 or 2500
/// a month, where a scan still costs 2.
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
    this.voiceLeft,
    this.voicePerCycle,
    this.imagesLeft,
    this.imagesPerCycle,
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
    int? n(String k) => switch (json[k]) {
      final num v => v.toInt(),
      _ => null,
    };
    return AttemptsBalance(
      tier: (json['tier'] as String?) ?? 'free',
      left: left.toInt(),
      perCycle: perCycle is num ? perCycle.toInt() : 20,
      nextRefillAt: next is String ? DateTime.tryParse(next) : null,
      adsEnabled: json['ads_enabled'] == true,
      adLeft: adLeft is num ? adLeft.toInt() : 0,
      voiceLeft: n('voice_free_left'),
      voicePerCycle: n('voice_per_cycle'),
      imagesLeft: n('images_left'),
      imagesPerCycle: n('images_per_cycle'),
    );
  }

  /// `free`, `starter`, `plus` or `pro`.
  final String tier;

  /// Attempts left now.
  final int left;

  /// What a cycle gives: 20 for the free tier, the plan's monthly figure
  /// otherwise.
  final int perCycle;

  /// When the balance comes back to [perCycle].
  final DateTime? nextRefillAt;

  /// Whether this tier sees ads.
  final bool adsEnabled;

  /// How much of [left] was earned from ads. It stays through the refill, so
  /// the cycle's own attempts are [left] less this.
  final int adLeft;

  /// Free tier: voice questions left in this cycle; null on a paid plan
  /// (no limit) or an older server.
  final int? voiceLeft;

  /// Free tier: voice questions a cycle gives (3).
  final int? voicePerCycle;

  /// Free tier: images left in this cycle; null on a paid plan or an older
  /// server, where a scan costs [AttemptCosts.scan] from [left].
  final int? imagesLeft;

  /// Free tier: images a cycle gives (2).
  final int? imagesPerCycle;

  /// Images come from their own balance (the free tier since 20261110210000).
  bool get imagesSeparate => imagesLeft != null;

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
      other.adLeft == adLeft &&
      other.voiceLeft == voiceLeft &&
      other.voicePerCycle == voicePerCycle &&
      other.imagesLeft == imagesLeft &&
      other.imagesPerCycle == imagesPerCycle;

  @override
  int get hashCode => Object.hash(
    tier,
    left,
    perCycle,
    nextRefillAt,
    adsEnabled,
    adLeft,
    voiceLeft,
    voicePerCycle,
    imagesLeft,
    imagesPerCycle,
  );
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
