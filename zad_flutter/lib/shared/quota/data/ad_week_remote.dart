/// The weekly conversion message's numbers (`zad_ad_week_status`, migration
/// 20261012060000): how many ads this customer watched in the last seven
/// days, and whether the message is due — free customers only, five ads or
/// more, once a week. The server decides; the phone only shows it.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/providers.dart';

/// The week in ads.
@immutable
class AdWeek {
  /// Creates one.
  const new({required this.show, required this.ads, required this.minutes});

  /// Reads the server's answer.
  factory fromJson(Map<String, dynamic> j) => AdWeek(
    show: j['show'] == true,
    ads: (j['ads'] as num?)?.toInt() ?? 0,
    minutes: (j['minutes'] as num?)?.toInt() ?? 0,
  );

  /// The message is due.
  final bool show;

  /// Ads watched in the last seven days.
  final int ads;

  /// About how long they took.
  final int minutes;
}

/// The server side, behind an interface for tests.
abstract interface class AdWeekRemote {
  /// `zad_ad_week_status()`.
  Future<AdWeek?> status();

  /// `zad_ad_week_seen()` — not again this week.
  Future<void> seen();
}

/// The real implementation.
class SupabaseAdWeekRemote implements AdWeekRemote {
  /// Creates it.
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<AdWeek?> status() async {
    final r = await _client.rpc<dynamic>('zad_ad_week_status');
    return r is Map ? AdWeek.fromJson(Map<String, dynamic>.from(r)) : null;
  }

  @override
  Future<void> seen() => _client.rpc<dynamic>('zad_ad_week_seen');
}

/// The remote in use.
final adWeekRemoteProvider = Provider<AdWeekRemote>(
  (ref) => SupabaseAdWeekRemote(ref.watch(supabaseClientProvider)),
);

/// This week's message, or null when there is none to show (not due,
/// signed out, offline, or an older server).
final FutureProvider<AdWeek?> adWeekProvider =
    FutureProvider.autoDispose<AdWeek?>((ref) async {
      try {
        final w = await ref.watch(adWeekRemoteProvider).status();
        return (w?.show ?? false) ? w : null;
      } on Object catch (e) {
        debugPrint('[ad-week] status failed: $e');
        return null;
      }
    });
