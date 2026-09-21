/// Stock readings for the server's consumption learner.
///
/// `zad_record_observation` stores a reading of how much of an item is on the
/// shelf, and `zad_recompute_consumption` turns the *drops between
/// consecutive readings* into a daily rate — which is what lets the brain say
/// "the milk runs out Thursday" instead of asking. Kotlin sends one every time
/// a receipt or the − button changes the pantry (Task 18); this client sends
/// one for a receipt, for − and +, and for a row added by hand.
///
/// Queued like every other write, one entry per reading: they are events, not
/// rows, so a later one must never replace an earlier one, and the outbox's
/// strict order keeps them in the order they happened.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zad/data/sync/outbox.dart';
import 'package:zad/data/sync/outbox_entry.dart';

/// Where a reading came from, as `zad_inventory_observations_source_check`
/// allows it.
abstract final class ObservationSource {
  /// A photographed receipt.
  static const String cameraOcr = 'camera_ocr';

  /// The customer's own count: the pantry's − and + buttons, or a row added
  /// by hand. Kotlin's source for the same buttons.
  static const String manual = 'manual';
}

/// The server side.
abstract interface class ObservationRemote {
  /// Calls `zad_record_observation`.
  Future<Object?> record({
    required String userId,
    required String item,
    required num quantity,
    required String source,
  });
}

/// The real function.
class SupabaseObservationRemote implements ObservationRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  @override
  Future<Object?> record({
    required String userId,
    required String item,
    required num quantity,
    required String source,
  }) => _client.rpc<dynamic>(
    'zad_record_observation',
    params: <String, dynamic>{
      'p_user': userId,
      'p_item': item,
      'p_qty': quantity,
      'p_source': source,
    },
  );
}

/// Queues readings and sends them.
class ConsumptionObservations {
  /// Creates the queue.
  const new({
    required ObservationRemote remote,
    required Outbox Function() outbox,
    required String Function() newId,
    required String? Function() signedInUserId,
  }) : _remote = remote,
       _outbox = outbox,
       _newId = newId,
       _signedInUserId = signedInUserId;

  final ObservationRemote _remote;
  final Outbox Function() _outbox;
  final String Function() _newId;
  final String? Function() _signedInUserId;

  /// Queues one reading: [quantity] of [item] on the shelf now.
  Future<void> record(String item, int quantity, String source) async {
    final userId = _signedInUserId();
    if (userId == null || userId.isEmpty) return;
    await _outbox().enqueue(
      id: 'observation:${_newId()}',
      kind: OutboxKind.recordObservation,
      payload: <String, dynamic>{
        'user_id': userId,
        'item': item,
        'qty': quantity,
        'source': source,
      },
    );
  }

  /// Sends one queued reading.
  Future<void> sendQueued(OutboxEntry entry) async {
    final result = await _remote.record(
      userId: entry.payload['user_id'] as String,
      item: entry.payload['item'] as String,
      quantity: entry.payload['qty'] as num,
      source: entry.payload['source'] as String,
    );
    // The function answers with what it learnt; no answer is no evidence the
    // reading was stored.
    if (result is! Map) {
      throw StateError('zad_record_observation answered $result');
    }
  }
}
