/// When a full-screen ad may show — the owner's rule of 2026-11-10.
///
/// One ad per navigation was rejected: AdMob and Google Play call that
/// "disruptive". So an interstitial shows only at a natural break (an expense
/// saved, a screen closed), and then only when every rule below allows it:
///
///   * never on the phone's first run (onboarding, the first look around),
///     nor in the first two minutes of any run;
///   * at least four minutes after the last one — longer for a customer who
///     leaves the app right after ads (see `PacerState.strikes`);
///   * at most four in any hour;
///   * not within five minutes of a rewarded ad the customer chose to watch.
///
/// Pure: the clock and the history come in, a yes or no goes out.
library;

import 'package:flutter/foundation.dart';

/// What the pacer knows.
@immutable
class PacerState {
  /// Creates a state.
  const new({
    required this.runStartedAt,
    this.firstRun = false,
    this.shown = const <DateTime>[],
    this.rewardedAt,
    this.strikes = 0,
    this.lastStrikeAt,
  });

  /// When this run of the app started.
  final DateTime runStartedAt;

  /// This is the first time the app ever ran on this phone.
  final bool firstRun;

  /// When interstitials showed, oldest first.
  final List<DateTime> shown;

  /// When the customer last finished a rewarded ad.
  final DateTime? rewardedAt;

  /// How many times the customer left the app within seconds of an
  /// interstitial closing. Each one doubles the gap, up to
  /// [InterstitialPacer.maxStrikes].
  final int strikes;

  /// When the last strike happened; strikes are forgotten after
  /// [InterstitialPacer.strikeMemory].
  final DateTime? lastStrikeAt;

  /// A copy with some fields changed.
  PacerState copyWith({
    List<DateTime>? shown,
    DateTime? rewardedAt,
    int? strikes,
    DateTime? lastStrikeAt,
  }) => PacerState(
    runStartedAt: runStartedAt,
    firstRun: firstRun,
    shown: shown ?? this.shown,
    rewardedAt: rewardedAt ?? this.rewardedAt,
    strikes: strikes ?? this.strikes,
    lastStrikeAt: lastStrikeAt ?? this.lastStrikeAt,
  );
}

/// The rules.
abstract final class InterstitialPacer {
  /// The shortest gap between two interstitials.
  static const Duration minGap = Duration(minutes: 4);

  /// The most in any rolling hour.
  static const int perHour = 4;

  /// No interstitial this soon after a rewarded ad.
  static const Duration afterRewarded = Duration(minutes: 5);

  /// No interstitial this early in a run.
  static const Duration warmUp = Duration(minutes: 2);

  /// Leaving the app this soon after an interstitial closed counts as a
  /// strike.
  static const Duration leaveWindow = Duration(seconds: 15);

  /// Strikes stop doubling the gap here (4 → 8 → 16 → 32 minutes).
  static const int maxStrikes = 3;

  /// Strikes are forgotten after this long without a new one.
  static const Duration strikeMemory = Duration(days: 3);

  /// Strikes still in force at [now].
  static int activeStrikes(PacerState s, DateTime now) {
    final at = s.lastStrikeAt;
    if (at == null || now.difference(at) > strikeMemory) return 0;
    return s.strikes.clamp(0, maxStrikes);
  }

  /// The gap in force at [now].
  static Duration gap(PacerState s, DateTime now) =>
      minGap * (1 << activeStrikes(s, now));

  /// Whether an interstitial may show at a break at [now].
  static bool mayShow(PacerState s, DateTime now) {
    if (s.firstRun) return false;
    if (now.difference(s.runStartedAt) < warmUp) return false;
    final rewarded = s.rewardedAt;
    if (rewarded != null && now.difference(rewarded) < afterRewarded) {
      return false;
    }
    if (s.shown.isNotEmpty && now.difference(s.shown.last) < gap(s, now)) {
      return false;
    }
    final hourAgo = now.subtract(const Duration(hours: 1));
    return s.shown.where((t) => t.isAfter(hourAgo)).length < perHour;
  }

  /// [s] after an interstitial showed at [now]; keeps the last hour only.
  static PacerState recordShown(PacerState s, DateTime now) {
    final hourAgo = now.subtract(const Duration(hours: 1));
    return s.copyWith(
      shown: <DateTime>[...s.shown.where((t) => t.isAfter(hourAgo)), now],
    );
  }

  /// [s] after the customer left the app at [now], an interstitial having
  /// closed at [closedAt].
  static PacerState recordLeave(PacerState s, DateTime closedAt, DateTime now) {
    if (now.difference(closedAt) > leaveWindow) return s;
    return s.copyWith(
      strikes: (activeStrikes(s, now) + 1).clamp(0, maxStrikes),
      lastStrikeAt: now,
    );
  }
}
