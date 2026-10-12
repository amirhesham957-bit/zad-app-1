/// Whether this phone may show an advert at all — the one rule every ad
/// placement asks before it loads anything (income plan 2026-10-11, §3).
///
/// No ads:
///   * in kids mode — Google Play's Families policy; the server refuses an
///     ad reward to a child account too (`zad_ad_reward_grant`,
///     'kids_no_ads'), so a modified app gains nothing;
///   * on a plan without ads (`ads_enabled` false, every paid tier);
///   * signed out.
///
/// AdMob is not in the app yet (no `google_mobile_ads`). When it lands, a
/// placement that does not read [adsAllowedProvider] first is a bug.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/kids/application/kids_mode_controller.dart';
import 'package:zad/shared/quota/application/attempts_balance_provider.dart';

/// Ads may show.
final adsAllowedProvider = Provider<bool>((ref) {
  if (ref.watch(sessionControllerProvider) == null) return false;
  if (ref.watch(kidsModeActiveProvider)) return false;
  final balance = ref.watch(attemptsBalanceProvider).value;
  // Unknown plan (offline, older server): the free default, which shows ads.
  return balance?.adsEnabled ?? true;
});
