/// رفيق زاد breaks the fourth wall (ZAD_PLAN ٥.٢): it notices you were
/// away, what time it is, that you are looking at the prices, and that you
/// keep poking it. Every line is built from something real on the phone —
/// the last time it saw you, the account's clock, the tap count — and none
/// calls a model, so it can speak the moment the app opens.
///
/// The weather the plan also names needs a location and a network call on
/// open; it is left for the server (zad-brain's weather.ts) to bring.
library;

import 'dart:math' as math;

import 'package:zad/core/l10n/l10n.dart';

/// A pause this long ends a burst of taps.
const Duration tapBurstWindow = Duration(seconds: 4);

/// A burst this long gets a line instead of the care sheet.
const int tapBurstMin = 5;

/// Away less than this is just a moment; the two-day sleep
/// (`companion_moments.dart`) takes over from 48 hours.
const Duration awayMin = Duration(hours: 6);

/// What the pet says to each of these, or null when nothing applies. In
/// [ZadL10n]'s language, Arabic by default.
abstract final class FourthWall {
  /// [count] taps in a row: from [tapBurstMin] on, it says so, with the
  /// number.
  static String? poked(
    int count, {
    required String name,
    math.Random? rng,
    ZadL10n? l10n,
  }) {
    if (count < tapBurstMin) return null;
    final l = l10n ?? zadL10nArabic;
    if (count >= 12) return l.petPokedMany(count);
    final r = rng ?? math.Random();
    return count >= 8
        ? l.petPokedLots('i${r.nextInt(2)}', count)
        : l.petPokedSome('i${r.nextInt(3)}', name);
  }

  /// Back after [away] (the phone's last sight of the pet): six hours to two
  /// days. Shorter is nothing; longer is the sleep moment's.
  static String? back(Duration away, {math.Random? rng, ZadL10n? l10n}) {
    if (away < awayMin || away >= const Duration(hours: 48)) return null;
    final l = l10n ?? zadL10nArabic;
    final i = 'i${(rng ?? math.Random()).nextInt(2)}';
    final hours = away.inHours;
    return hours >= 24 ? l.petBackDay(i) : l.petBackHours(i, hours);
  }

  /// The account's [hour] (0–23): the small hours and the early morning.
  static String? clock(int hour, {math.Random? rng, ZadL10n? l10n}) {
    final l = l10n ?? zadL10nArabic;
    final i = 'i${(rng ?? math.Random()).nextInt(2)}';
    return switch (hour) {
      >= 0 && < 4 => l.petClockNight(i, hour),
      >= 4 && < 7 => l.petClockDawn(i),
      _ => null,
    };
  }

  /// On the subscription screen.
  static String paywall({
    required String name,
    math.Random? rng,
    ZadL10n? l10n,
  }) => (l10n ?? zadL10nArabic).petPaywall(
    'i${(rng ?? math.Random()).nextInt(3)}',
    name,
  );
}
