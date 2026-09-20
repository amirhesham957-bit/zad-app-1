/// The server side of the bank channel.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Hands a notification to `zad-brain`.
abstract interface class BankRemote {
  /// Calls the `notification_ingest` action.
  ///
  /// Returns the server's `status` — `logged`, `ignored`,
  /// `awaiting_confirmation`, `ambiguous`. Throws on transport failure, which
  /// is what lets the outbox tell a retryable outage from a refusal.
  Future<String?> ingestNotification(Map<String, dynamic> payload);
}

/// The real implementation.
class SupabaseBankRemote implements BankRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<String?> ingestNotification(Map<String, dynamic> payload) async {
    // 20s, matching the Kotlin listener: the server may be waking a cold
    // function and running a model over the message.
    final response = await _client.functions.invoke('zad-brain', body: payload);

    final data = response.data;
    if (data is Map && data['status'] != null) return '${data['status']}';
    return null;
  }
}
