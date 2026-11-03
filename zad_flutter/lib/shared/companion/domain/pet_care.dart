/// رفيق زاد as a virtual pet: it gets hungry, thirsty and sleepy, and the
/// customer feeds it, gives it water and pets it once or twice a day.
///
/// Kept on the phone, per account — it grants nothing. XP, levels and seeds
/// stay the server's (ZAD_COMPANION.md: "السيرفر بس هو اللي بيدّي XP"), so a
/// tap here can never be farmed into currency. And the companion's mercy rule
/// holds: a neglected pet is sad, never sick, never gone.
///
/// Every level is a straight line from a moment it was full: `fedAt` is when
/// the tummy was last 100%, so fullness at any instant is one subtraction and
/// nothing has to tick in the background.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';

/// What came of a feed or a drink.
enum PetCareOutcome {
  /// Eaten or drunk.
  done,

  /// Already full: nothing changed.
  full,
}

/// The pet's care, as stored.
@immutable
class PetCare {
  /// Creates one.
  const new({
    required this.fedAt,
    required this.wateredAt,
    this.pettedAt,
    this.lastCareAt,
    this.fedDay,
    this.wateredDay,
    this.careDay,
    this.careStreak = 0,
  });

  /// A pet met for the first time: a little hungry, so the first thing the
  /// customer learns is that it eats.
  factory newborn(DateTime now) => PetCare(
    fedAt: now.subtract(hungerSpan * 0.78),
    wateredAt: now.subtract(thirstSpan * 0.4),
  );

  /// Reads [toJson]; null for anything unreadable.
  static PetCare? fromJson(Object? j) {
    if (j is! Map) return null;
    final fed = DateTime.tryParse('${j['fed_at']}');
    final watered = DateTime.tryParse('${j['watered_at']}');
    if (fed == null || watered == null) return null;
    DateTime? at(String k) =>
        j[k] == null ? null : DateTime.tryParse('${j[k]}');
    String? day(String k) => j[k] is String ? j[k] as String : null;
    return PetCare(
      fedAt: fed,
      wateredAt: watered,
      pettedAt: at('petted_at'),
      lastCareAt: at('last_care_at'),
      fedDay: day('fed_day'),
      wateredDay: day('watered_day'),
      careDay: day('care_day'),
      careStreak: j['care_streak'] is num
          ? (j['care_streak'] as num).toInt()
          : 0,
    );
  }

  /// Full to empty: about two meals a day.
  static const Duration hungerSpan = Duration(hours: 20);

  /// Full to empty: thirst comes faster than hunger.
  static const Duration thirstSpan = Duration(hours: 14);

  /// A pat's warmth lasts this long.
  static const Duration joySpan = Duration(hours: 36);

  /// Below this a need shows.
  static const double needBelow = 0.3;

  /// What one meal or one drink fills.
  static const double serving = 0.5;

  /// When the tummy was last full.
  final DateTime fedAt;

  /// When it last had all the water it wanted.
  final DateTime wateredAt;

  /// The last pat.
  final DateTime? pettedAt;

  /// The last feed, drink or pat — it stays pleased for a while after.
  final DateTime? lastCareAt;

  /// The account-day (yyyy-mm-dd) of the last meal.
  final String? fedDay;

  /// The account-day of the last drink.
  final String? wateredDay;

  /// The last account-day it was both fed and given water.
  final String? careDay;

  /// Days in a row it was both fed and given water.
  final int careStreak;

  /// 1 full, 0 starving.
  double fullness(DateTime now) => _level(fedAt, hungerSpan, now);

  /// 1 quenched, 0 parched.
  double hydration(DateTime now) => _level(wateredAt, thirstSpan, now);

  /// 1 just petted, 0 not for a day and a half.
  double joy(DateTime now) {
    final p = pettedAt;
    return p == null ? 0 : _level(p, joySpan, now);
  }

  static double _level(DateTime full, Duration span, DateTime now) {
    final gone = now.difference(full).inSeconds / span.inSeconds;
    return (1 - gone).clamp(0.0, 1.0);
  }

  /// The pet's mood at [now]. [hour] is the account's clock: 23:00–06:00 it
  /// is sleepy whatever else, unless it was just looked after.
  CompanionState mood(DateTime now, {required int hour}) {
    final f = fullness(now);
    final w = hydration(now);
    final last = lastCareAt;
    final justCared =
        last != null && now.difference(last) < const Duration(minutes: 15);
    if (hour >= 23 || hour < 6) {
      return justCared ? CompanionState.happy : CompanionState.sleepy;
    }
    if (f < 0.15 && w < 0.15) return CompanionState.sad;
    // Thirst first: it comes faster and is the more urgent of the two.
    if (w < needBelow) return CompanionState.thirsty;
    if (f < needBelow) return CompanionState.hungry;
    if (justCared) return CompanionState.happy;
    if (f > 0.6 && w > 0.6 && joy(now) > 0.3) return CompanionState.happy;
    return CompanionState.idle;
  }

  /// The first instant a need will show, or null when one already shows.
  DateTime? nextNeedAt(DateTime now) {
    final hungry = fedAt.add(hungerSpan * (1 - needBelow));
    final thirsty = wateredAt.add(thirstSpan * (1 - needBelow));
    final first = hungry.isBefore(thirsty) ? hungry : thirsty;
    return first.isAfter(now) ? first : null;
  }

  /// One meal. [day] is the account's yyyy-mm-dd, [yesterday] the day
  /// before it — for the care streak.
  (PetCare, PetCareOutcome) feed(
    DateTime now, {
    required String day,
    required String yesterday,
  }) {
    final f = fullness(now);
    if (f >= 0.95) return (this, PetCareOutcome.full);
    final filled = math.min(1, f + serving);
    return (
      _copy(
        fedAt: now.subtract(hungerSpan * (1 - filled)),
        lastCareAt: now,
        fedDay: day,
      )._streak(day, yesterday),
      PetCareOutcome.done,
    );
  }

  /// One drink; see [feed].
  (PetCare, PetCareOutcome) water(
    DateTime now, {
    required String day,
    required String yesterday,
  }) {
    final w = hydration(now);
    if (w >= 0.95) return (this, PetCareOutcome.full);
    final filled = math.min(1, w + serving);
    return (
      _copy(
        wateredAt: now.subtract(thirstSpan * (1 - filled)),
        lastCareAt: now,
        wateredDay: day,
      )._streak(day, yesterday),
      PetCareOutcome.done,
    );
  }

  /// A pat — always welcome.
  PetCare pet(DateTime now) => _copy(pettedAt: now, lastCareAt: now);

  PetCare _streak(String day, String yesterday) {
    if (fedDay != day || wateredDay != day || careDay == day) return this;
    return _copy(
      careDay: day,
      careStreak: careDay == yesterday ? careStreak + 1 : 1,
    );
  }

  PetCare _copy({
    DateTime? fedAt,
    DateTime? wateredAt,
    DateTime? pettedAt,
    DateTime? lastCareAt,
    String? fedDay,
    String? wateredDay,
    String? careDay,
    int? careStreak,
  }) => PetCare(
    fedAt: fedAt ?? this.fedAt,
    wateredAt: wateredAt ?? this.wateredAt,
    pettedAt: pettedAt ?? this.pettedAt,
    lastCareAt: lastCareAt ?? this.lastCareAt,
    fedDay: fedDay ?? this.fedDay,
    wateredDay: wateredDay ?? this.wateredDay,
    careDay: careDay ?? this.careDay,
    careStreak: careStreak ?? this.careStreak,
  );

  /// The stored shape.
  Map<String, Object?> toJson() => <String, Object?>{
    'fed_at': fedAt.toUtc().toIso8601String(),
    'watered_at': wateredAt.toUtc().toIso8601String(),
    'petted_at': pettedAt?.toUtc().toIso8601String(),
    'last_care_at': lastCareAt?.toUtc().toIso8601String(),
    'fed_day': fedDay,
    'watered_day': wateredDay,
    'care_day': careDay,
    'care_streak': careStreak,
  };
}

/// What the pet says, in [ZadL10n]'s language (Arabic by default).
abstract final class PetLines {
  /// A line for [mood]. [loggedToday] nudges toward the day's habit when
  /// nothing is wrong.
  static String forMood(
    CompanionState mood, {
    required String name,
    required bool loggedToday,
    math.Random? rng,
    ZadL10n? l10n,
  }) {
    final r = rng ?? math.Random();
    final l = l10n ?? zadL10nArabic;
    String i(int n) => 'i${r.nextInt(n)}';
    return switch (mood) {
      CompanionState.hungry => l.petMoodHungry(i(3)),
      CompanionState.thirsty => l.petMoodThirsty(i(3)),
      CompanionState.sleepy => l.petMoodSleepy(i(3)),
      CompanionState.sad => l.petMoodSad(i(2), name),
      CompanionState.happy ||
      CompanionState.celebrating => l.petMoodHappy(i(3)),
      _ => loggedToday ? l.petMoodLogged(i(3)) : l.petMoodNudge(i(2)),
    };
  }

  /// After a meal.
  static String fed(PetCareOutcome o, {math.Random? rng, ZadL10n? l10n}) {
    final l = l10n ?? zadL10nArabic;
    return switch (o) {
      PetCareOutcome.done => l.petFed(_i(3, rng)),
      PetCareOutcome.full => l.petFull(_i(2, rng)),
    };
  }

  /// After a drink.
  static String watered(PetCareOutcome o, {math.Random? rng, ZadL10n? l10n}) {
    final l = l10n ?? zadL10nArabic;
    return switch (o) {
      PetCareOutcome.done => l.petWatered(_i(2, rng)),
      PetCareOutcome.full => l.petWaterFull(_i(2, rng)),
    };
  }

  /// After a pat.
  static String petted({math.Random? rng, ZadL10n? l10n}) =>
      (l10n ?? zadL10nArabic).petPetted(_i(3, rng));

  /// One of [n] lines, as the ARB's select key.
  static String _i(int n, math.Random? rng) =>
      'i${(rng ?? math.Random()).nextInt(n)}';
}
