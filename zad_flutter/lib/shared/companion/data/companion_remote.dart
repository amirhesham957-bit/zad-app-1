/// The companion's server calls (migration 20261012030000). Every one answers
/// for `auth.uid()`; none takes a user id, so none can act for anyone else.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/companion/domain/companion_status.dart';

/// What a buy, a wear or a code returned: ok, or the server's reason.
typedef CompanionResult = ({bool ok, String? reason, int? missing});

/// The server side, behind an interface so screens can be tested offline.
abstract interface class CompanionRemote {
  /// `zad_companion_status()` — also the check-in and the lazy unlocks.
  Future<CompanionStatus?> status();

  /// `zad_companion_ack()` — the celebration was shown.
  Future<void> ack();

  /// `zad_companion_equip(p_item)`; 'none' takes the outfit off.
  Future<CompanionResult> equip(String item);

  /// `zad_companion_buy(p_item, p_season)` with seeds.
  Future<CompanionResult> buy(String item, {String? season});

  /// `zad_companion_claim_invite(p_code)`.
  Future<CompanionResult> claimInvite(String code);
}

/// The real implementation.
class SupabaseCompanionRemote implements CompanionRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<CompanionStatus?> status() async {
    final r = await _client.rpc<dynamic>('zad_companion_status');
    if (r is! Map) return null;
    return CompanionStatus.fromJson(Map<String, dynamic>.from(r));
  }

  @override
  Future<void> ack() => _client.rpc<dynamic>('zad_companion_ack');

  @override
  Future<CompanionResult> equip(String item) async => _read(
    await _client.rpc<dynamic>(
      'zad_companion_equip',
      params: <String, dynamic>{'p_item': item},
    ),
  );

  @override
  Future<CompanionResult> buy(String item, {String? season}) async => _read(
    await _client.rpc<dynamic>(
      'zad_companion_buy',
      params: <String, dynamic>{'p_item': item, 'p_season': season},
    ),
  );

  @override
  Future<CompanionResult> claimInvite(String code) async => _read(
    await _client.rpc<dynamic>(
      'zad_companion_claim_invite',
      params: <String, dynamic>{'p_code': code},
    ),
  );

  static CompanionResult _read(Object? r) {
    if (r is! Map) return (ok: false, reason: 'offline', missing: null);
    return (
      ok: r['ok'] == true,
      reason: r['reason'] as String?,
      missing: (r['missing'] as num?)?.toInt(),
    );
  }
}

/// The remote in use.
final companionRemoteProvider = Provider<CompanionRemote>(
  (ref) => SupabaseCompanionRemote(ref.watch(supabaseClientProvider)),
);
