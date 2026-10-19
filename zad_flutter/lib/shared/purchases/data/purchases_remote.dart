/// The server side of the purchase door.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Records purchases and reads back the expense they became.
abstract interface class PurchasesRemote {
  /// Calls `zad_record_purchase`. Refusals are answers, not errors.
  Future<Map<String, dynamic>> record(Map<String, dynamic> purchase);

  /// The expense row [id], or null when there is none.
  Future<Map<String, dynamic>?> fetchTransaction(String id);
}

/// The real one.
class SupabasePurchasesRemote implements PurchasesRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>> record(Map<String, dynamic> purchase) async {
    final result = await _client.rpc<dynamic>(
      'zad_record_purchase',
      params: <String, dynamic>{'p_purchase': purchase},
    );
    if (result is! Map) {
      throw StateError('zad_record_purchase answered $result');
    }
    return Map<String, dynamic>.from(result);
  }

  @override
  Future<Map<String, dynamic>?> fetchTransaction(String id) =>
      _client.from('zad_transactions').select().eq('id', id).maybeSingle();
}
