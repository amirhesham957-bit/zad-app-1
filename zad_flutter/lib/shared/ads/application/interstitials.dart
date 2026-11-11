/// Full-screen ads at natural breaks, paced by [InterstitialPacer].
///
/// A break is reported with [Interstitials.atBreak] — an expense saved, a
/// screen closed. Nothing shows unless [adsAllowedProvider] says ads may show
/// (no kids mode, no paid plan), the build has an interstitial unit, an ad is
/// already loaded, and the pacer agrees. The pacer's history lives on this
/// phone, so the pace survives a restart.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/ads/application/ads_policy.dart';
import 'package:zad/shared/ads/data/interstitial_ads.dart';
import 'package:zad/shared/ads/domain/interstitial_pacer.dart';

/// A natural break in what the customer is doing.
enum InterstitialBreak {
  /// An expense or income was saved and its sheet closed.
  saved,

  /// A full screen was closed with back.
  screenClosed,

  /// Zad answered an AI request in the chat. Only every
  /// [Interstitials.aiRepliesPerAd]th one is a break (owner 11/11), and it
  /// comes after the reply is on screen, never before it.
  aiReply,

  /// A scanned receipt was saved (owner 11/11: an ad with every scan).
  scanSaved,
}

/// The pacing and the showing.
class Interstitials with WidgetsBindingObserver {
  /// Creates it and starts listening to the app's lifecycle.
  new(this._ref) {
    final box = _boxOrNull;
    final firstRun = box?.get(_runKey) == null;
    _put(_runKey, '1');
    _state = PacerState(
      runStartedAt: _now(),
      firstRun: firstRun,
      shown: _times(box?.get(_shownKey)),
      strikes: int.tryParse(box?.get(_strikesKey) ?? '') ?? 0,
      lastStrikeAt: _time(box?.get(_strikeAtKey)),
    );
    WidgetsBinding.instance.addObserver(this);
  }

  final Ref _ref;
  late PacerState _state;
  DateTime? _closedAt;
  bool _showing = false;
  int _aiReplies = 0;

  /// Every how many AI replies one is a break.
  static const int aiRepliesPerAd = 3;

  static const String _runKey = 'ads_inter_ran';
  static const String _shownKey = 'ads_inter_shown';
  static const String _strikesKey = 'ads_inter_strikes';
  static const String _strikeAtKey = 'ads_inter_strike_at';

  /// The phone's store, or null where there is none (a widget test that
  /// never set one up); without it the pacer treats every run as the first,
  /// so nothing shows.
  Box<String>? get _boxOrNull {
    try {
      return _ref.read(localStoreProvider).device;
    } on Object {
      return null;
    }
  }

  void _put(String key, String value) {
    final box = _boxOrNull;
    if (box != null) unawaited(box.put(key, value));
  }

  DateTime _now() => _ref.read(nowProvider)();

  /// The pacer's view, for tests.
  @visibleForTesting
  PacerState get state => _state;

  /// A rewarded ad finished: no interstitial right after it.
  void rewardedShown() => _state = _state.copyWith(rewardedAt: _now());

  /// Loads one ahead when ads may show; cheap to call often.
  void warmUp() {
    if (!_ref.read(adsAllowedProvider)) return;
    final ads = _ref.read(interstitialAdsProvider);
    if (ads.configured) unawaited(ads.preload());
  }

  /// A break happened; shows an ad if every rule allows. Answers whether
  /// one showed.
  Future<bool> atBreak(InterstitialBreak kind) async {
    if (_showing || !_ref.read(adsAllowedProvider)) return false;
    if (kind == InterstitialBreak.aiReply &&
        ++_aiReplies % aiRepliesPerAd != 0) {
      warmUp();
      return false;
    }
    final ads = _ref.read(interstitialAdsProvider);
    if (!ads.configured) return false;
    final now = _now();
    if (!InterstitialPacer.mayShow(_state, now)) {
      unawaited(ads.preload());
      return false;
    }
    _showing = true;
    try {
      final shown = await ads.showReady();
      if (shown) {
        _state = InterstitialPacer.recordShown(_state, now);
        _closedAt = _now();
        _put(
          _shownKey,
          _state.shown.map((t) => t.millisecondsSinceEpoch).join(','),
        );
      }
      unawaited(ads.preload());
      return shown;
    } finally {
      _showing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused || _showing) return;
    final closed = _closedAt;
    if (closed == null) return;
    final before = _state.lastStrikeAt;
    _state = InterstitialPacer.recordLeave(_state, closed, _now());
    _closedAt = null;
    final at = _state.lastStrikeAt;
    if (at != null && at != before) {
      _put(_strikesKey, '${_state.strikes}');
      _put(_strikeAtKey, '${at.millisecondsSinceEpoch}');
    }
  }

  /// Stops listening.
  void dispose() => WidgetsBinding.instance.removeObserver(this);

  static DateTime? _time(String? ms) {
    final v = int.tryParse(ms ?? '');
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
  }

  static List<DateTime> _times(String? raw) =>
      (raw ?? '').split(',').map(_time).whereType<DateTime>().toList();
}

/// The one instance.
final interstitialsProvider = Provider<Interstitials>((ref) {
  final i = Interstitials(ref);
  ref.onDispose(i.dispose);
  return i;
});

/// Reports [InterstitialBreak.screenClosed] when a full screen is popped.
/// Sheets and dialogs are not screens and do not count.
class InterstitialRouteObserver extends NavigatorObserver {
  /// Creates it.
  new(this._interstitials);

  final Interstitials Function() _interstitials;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute<dynamic> || previousRoute == null) return;
    unawaited(_interstitials().atBreak(InterstitialBreak.screenClosed));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute<dynamic>) _interstitials().warmUp();
  }
}
