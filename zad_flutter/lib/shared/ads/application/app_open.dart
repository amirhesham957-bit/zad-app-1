/// The App Open ad: one when the customer comes back after four hours or
/// more away (ZAD_PLAN ١٠.٣ د) — a return, the moment AdMob built this
/// format for, never in the middle of a task.
///
/// No ad unless every rule allows:
///   * the build has an App Open unit (`ADMOB_APP_OPEN_UNIT`; empty = off);
///   * ads may show ([adsAllowedProvider]: no kids mode, signed in) *and* the
///     server has said this plan carries ads — a paid customer coming back
///     is never shown one while the plan is still loading;
///   * not the phone's first run, and the customer was really away
///     [AppOpenRule.minAbsence] or more — counted from when the app last
///     went to the background, across restarts;
///   * no other full-screen ad is on screen.
///
/// After one shows, the interstitial pacer holds off as it does after a
/// rewarded ad, so two full-screen ads never come back to back.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/ads/application/interstitials.dart';
import 'package:zad/shared/ads/data/app_open_ads.dart';
import 'package:zad/shared/quota/application/attempts_balance_provider.dart';

/// When a return carries an App Open ad. Pure.
abstract final class AppOpenRule {
  /// Away at least this long.
  static const Duration minAbsence = Duration(hours: 4);

  /// Whether a return at [now], the app having left at [leftAt], qualifies.
  static bool qualifies({required DateTime? leftAt, required DateTime now}) =>
      leftAt != null && now.difference(leftAt) >= minAbsence;
}

/// Watches the app go and come back.
class AppOpen with WidgetsBindingObserver {
  /// Creates it, checks a cold start, and starts listening.
  new(this._ref) {
    WidgetsBinding.instance.addObserver(this);
    // A cold start after a long absence is a return too.
    // After the provider has built, not inside its build.
    scheduleMicrotask(() => unawaited(_onReturn()));
  }

  final Ref _ref;
  bool _busy = false;

  static const String _leftKey = 'ads_open_left';

  Box<String>? get _boxOrNull {
    try {
      return _ref.read(localStoreProvider).device;
    } on Object {
      return null;
    }
  }

  DateTime _now() => _ref.read(nowProvider)();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !_busy) {
      final box = _boxOrNull;
      if (box != null) {
        unawaited(box.put(_leftKey, '${_now().millisecondsSinceEpoch}'));
      }
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_onReturn());
    }
  }

  /// A return; answers whether an ad showed. Visible for tests.
  @visibleForTesting
  Future<bool> onReturnForTest() => _onReturn();

  Future<bool> _onReturn() async {
    if (_busy) return false;
    final box = _boxOrNull;
    if (box == null) return false;
    final leftAt = DateTime.fromMillisecondsSinceEpoch(
      int.tryParse(box.get(_leftKey) ?? '') ?? 0,
    );
    final now = _now();
    // Stamped now, so the return is counted once even if the app is killed
    // before it goes to the background again. A first run has no stamp.
    final hadStamp = box.get(_leftKey) != null;
    unawaited(box.put(_leftKey, '${now.millisecondsSinceEpoch}'));
    if (!hadStamp || !AppOpenRule.qualifies(leftAt: leftAt, now: now)) {
      return false;
    }
    final ads = _ref.read(appOpenAdsProvider);
    if (!ads.configured || !_ref.read(adsAllowedProvider)) return false;
    _busy = true;
    try {
      if (!await _planCarriesAds()) return false;
      if (!_ref.read(adsAllowedProvider)) return false;
      final shown = await ads.loadAndShow();
      if (shown) _ref.read(interstitialsProvider).rewardedShown();
      return shown;
    } finally {
      _busy = false;
    }
  }

  /// The server's answer, waited for within the ad's own deadline.
  Future<bool> _planCarriesAds() async {
    final keep = _ref.listen(attemptsBalanceProvider, (_, _) {});
    try {
      final balance = await _ref
          .read(attemptsBalanceProvider.future)
          .timeout(AppOpenAds.loadDeadline);
      return balance?.adsEnabled ?? false;
    } on Object {
      return false;
    } finally {
      keep.close();
    }
  }

  /// Stops listening.
  void dispose() => WidgetsBinding.instance.removeObserver(this);
}

/// The one instance; read once by the app shell.
final appOpenProvider = Provider<AppOpen>((ref) {
  final a = AppOpen(ref);
  ref.onDispose(a.dispose);
  return a;
});
