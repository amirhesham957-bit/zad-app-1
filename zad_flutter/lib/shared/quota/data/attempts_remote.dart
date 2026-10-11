/// Reads the balance from the server. The phone never computes it: the server
/// spends it, refills it and is the only one that knows it.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/shared/quota/domain/attempts_balance.dart';

/// The server side, behind an interface so the chip can be tested offline.
abstract interface class AttemptsRemote {
  /// Calls `zad_entitlement_status(p_tz)` for the signed-in customer.
  Future<AttemptsBalance?> fetch({required String timeZone});
}

/// The real implementation.
class SupabaseAttemptsRemote implements AttemptsRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<AttemptsBalance?> fetch({required String timeZone}) async {
    // No p_user: the function answers for auth.uid() and refuses anyone else.
    final result = await _client.rpc<dynamic>(
      'zad_entitlement_status',
      params: <String, dynamic>{'p_tz': timeZone},
    );
    if (result is! Map) return null;
    return AttemptsBalance.fromStatus(Map<String, dynamic>.from(result));
  }
}

/// The remote in use.
final attemptsRemoteProvider = Provider<AttemptsRemote>(
  (ref) => SupabaseAttemptsRemote(ref.watch(supabaseClientProvider)),
);
