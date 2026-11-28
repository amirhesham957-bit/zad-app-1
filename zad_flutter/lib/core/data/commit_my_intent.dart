/// The one door, from a button (P1.6b): `zad_commit_my_intent`.
///
/// The wrapper takes the user from the JWT and the source is always `manual`,
/// so a button can never write for someone else or pose as the model. One trace
/// id per call goes in as `p_trace_id` and ends up on the `zad_events` row
/// (P1.7), the same id [invokeEdge] sends for edge functions.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/core/data/edge_client.dart';
import 'package:zad/core/data/sync/sync_failure.dart';

/// The server function every button writes through.
const String commitMyIntentFunction = 'zad_commit_my_intent';

/// Sends one intent and returns the door's answer.
///
/// A refusal (`reason` on `ok: false`) throws [ServerRefusal], which the outbox
/// treats as permanent; `not_authenticated` throws [AuthException] instead, as
/// the session is what is wrong, not the write. A replay answers `duplicate`
/// with `ok: true` and wrote nothing, which is success.
Future<Map<String, dynamic>> commitMyIntent(
  SupabaseClient client, {
  required String kind,
  required String clientEventId,
  required Map<String, dynamic> payload,
  DateTime? occurredAt,
}) async {
  final answer = await client.rpc<dynamic>(
    commitMyIntentFunction,
    params: <String, dynamic>{
      'p_kind': kind,
      'p_client_event_id': clientEventId,
      'p_payload': payload,
      if (occurredAt != null)
        'p_occurred_at': occurredAt.toUtc().toIso8601String(),
      'p_trace_id': newTraceId(),
    },
  );
  final result = Map<String, dynamic>.from(answer as Map);
  if (result['ok'] != true) {
    final reason = (result['reason'] as String?) ?? 'unknown';
    if (reason == 'not_authenticated') throw AuthException(reason);
    throw ServerRefusal(commitMyIntentFunction, reason);
  }
  return result;
}
