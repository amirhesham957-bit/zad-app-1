/// What the next rewarded ad would give (`zad_ad_reward_preview`, migration
/// 20261013120000) — asked before the ad, so nobody watches thirty seconds
/// for a grant the server then refuses (the day's cap, the minute between
/// two, a child's account).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/providers.dart';

/// The next ad, as the server sees it.
@immutable
class AdRewardPreview {
  /// Creates one.
  const new({
    required this.available,
    this.reason,
    this.reward = 0,
    this.boxNext = false,
    this.boxBonus = 0,
    this.adsToday = 0,
    this.dailyCap = 10,
    this.waitSeconds = 0,
  });

  /// Reads the server's answer.
  factory fromJson(Map<String, dynamic> j) => AdRewardPreview(
    available: j['available'] == true,
    reason: j['reason'] as String?,
    reward: (j['reward'] as num?)?.toInt() ?? 0,
    boxNext: j['box_next'] == true,
    boxBonus: (j['box_bonus'] as num?)?.toInt() ?? 0,
    adsToday: (j['ads_today'] as num?)?.toInt() ?? 0,
    dailyCap: (j['daily_cap'] as num?)?.toInt() ?? 10,
    waitSeconds: (j['wait_seconds'] as num?)?.toInt() ?? 0,
  );

  /// The next ad would be granted (now or after [waitSeconds]).
  final bool available;

  /// Why not: `daily_ad_cap` or `kids_no_ads`.
  final String? reason;

  /// Attempts for one ad, before the box.
  final int reward;

  /// The next ad opens the box.
  final bool boxNext;

  /// What the box adds.
  final int boxBonus;

  /// Ads granted today (UTC).
  final int adsToday;

  /// The most there can be in a day.
  final int dailyCap;

  /// Seconds until the next ad counts.
  final int waitSeconds;

  /// What the next ad gives in all.
  int get total => reward + (boxNext ? boxBonus : 0);

  /// The day's ads are used up.
  bool get capped => reason == 'daily_ad_cap';
}

/// The server side, behind an interface for tests.
abstract interface class AdRewardPreviewRemote {
  /// `zad_ad_reward_preview()`.
  Future<AdRewardPreview?> preview();
}

/// The real implementation.
class SupabaseAdRewardPreviewRemote implements AdRewardPreviewRemote {
  /// Creates it.
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<AdRewardPreview?> preview() async {
    final r = await _client.rpc<dynamic>('zad_ad_reward_preview');
    return r is Map
        ? AdRewardPreview.fromJson(Map<String, dynamic>.from(r))
        : null;
  }
}

/// The remote in use.
final adRewardPreviewRemoteProvider = Provider<AdRewardPreviewRemote>(
  (ref) => SupabaseAdRewardPreviewRemote(ref.watch(supabaseClientProvider)),
);

/// The next ad, or null when there is nothing to offer (offline, signed out,
/// or a server without the preview).
final FutureProvider<AdRewardPreview?> adRewardPreviewProvider =
    FutureProvider.autoDispose<AdRewardPreview?>((ref) async {
      try {
        return await ref.watch(adRewardPreviewRemoteProvider).preview();
      } on Object catch (e) {
        debugPrint('[ads] preview failed: $e');
        return null;
      }
    });
