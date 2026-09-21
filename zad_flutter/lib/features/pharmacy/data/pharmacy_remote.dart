/// The server side of the pharmacy.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// What the dose RPC answered.
class DoseReceipt {
  /// Creates a receipt.
  const new({
    required this.ok,
    required this.duplicate,
    this.remainingQuantity,
    this.reason,
    this.shoppingAdded = false,
  });

  /// Reads `zad_log_pharmacy_dose_atomic`'s jsonb.
  factory fromJson(Map<String, dynamic> json) => DoseReceipt(
    ok: json['ok'] as bool? ?? false,
    duplicate: json['duplicate'] as bool? ?? false,
    remainingQuantity: (json['remaining_quantity'] as num?)?.toInt(),
    reason: json['reason'] as String?,
    shoppingAdded: json['shopping_added'] as bool? ?? false,
  );

  /// Whether the dose was accepted.
  final bool ok;

  /// Whether this slot had already been recorded.
  ///
  /// Not a failure. The RPC inserts `on conflict (user_id, item_id,
  /// scheduled_at) do nothing`, which is what makes a retry after an ambiguous
  /// network failure safe — and this flag is how the client tells "recorded"
  /// from "recorded twice ago".
  final bool duplicate;

  /// What is left after the decrement.
  final int? remainingQuantity;

  /// Why it was refused — `invalid_input`, `not_found`.
  final String? reason;

  /// Whether the server put the medicine on the shopping list because this
  /// dose took it under a day's worth.
  final bool shoppingAdded;
}

/// Reads and writes the pharmacy.
abstract interface class PharmacyRemote {
  /// Every medicine the account can see.
  Future<List<Map<String, dynamic>>> fetchMedicines({required String userId});

  /// Recorded doses since [since], from both tables the server checks.
  ///
  /// Both, because they are written by different paths: the RPC writes
  /// `zad_pharmacy_doses`, while `zad_dose_log` carries what the older alarm
  /// path recorded. `zad_enqueue_missed_doses` treats either as an answer, so
  /// a client reading only one would show a dose as missed that the server has
  /// already counted.
  Future<List<DateTime>> fetchDoseRecords({
    required String userId,
    required String medicineId,
    required DateTime since,
  });

  /// Inserts or updates a medicine, returning what the row holds afterwards.
  Future<Map<String, dynamic>?> upsertReturning(Map<String, dynamic> row);

  /// Records a dose through `zad_log_pharmacy_dose_atomic`.
  Future<DoseReceipt> logDose({
    required String userId,
    required String medicineId,
    DateTime? scheduledAt,
    DateTime? takenAt,
  });

  /// Removes a medicine.
  Future<void> remove(String id);
}

/// The real pharmacy.
class SupabasePharmacyRemote implements PharmacyRemote {
  /// Creates a remote over a Supabase client.
  const new(this._client);

  final SupabaseClient _client;

  static const String _items = 'zad_pharmacy_items';
  static const String _doses = 'zad_pharmacy_doses';
  static const String _log = 'zad_dose_log';

  @override
  Future<List<Map<String, dynamic>>> fetchMedicines({
    required String userId,
  }) async {
    final rows = await _client
        .from(_items)
        .select()
        .eq('user_id', userId)
        .order('name');
    return rows.cast<Map<String, dynamic>>();
  }

  @override
  Future<List<DateTime>> fetchDoseRecords({
    required String userId,
    required String medicineId,
    required DateTime since,
  }) async {
    final from = since.toUtc().toIso8601String();

    final doses = await _client
        .from(_doses)
        .select('taken_at, scheduled_at, status')
        .eq('user_id', userId)
        .eq('item_id', medicineId)
        .eq('status', 'taken')
        .gte('scheduled_at', from);

    final logged = await _client
        .from(_log)
        .select('taken_at')
        .eq('user_id', userId)
        .eq('pharmacy_item_id', medicineId)
        .gte('taken_at', from);

    return <DateTime>[
      // `coalesce(taken_at, scheduled_at)` — the same fallback the cron's
      // exists-check uses, because a dose row may carry only the slot.
      for (final row in doses)
        ?readInstant(row['taken_at'] ?? row['scheduled_at']),
      for (final row in logged) ?readInstant(row['taken_at']),
    ]..sort();
  }

  @override
  Future<Map<String, dynamic>?> upsertReturning(
    Map<String, dynamic> row,
  ) async {
    await _client.from(_items).upsert(row, onConflict: 'id');
    return await _client
        .from(_items)
        .select()
        .eq('id', row['id'] as String)
        .maybeSingle();
  }

  @override
  Future<DoseReceipt> logDose({
    required String userId,
    required String medicineId,
    DateTime? scheduledAt,
    DateTime? takenAt,
  }) async {
    // The RPC, not an insert. It writes the dose, decrements
    // `remaining_quantity` carrying the fraction, and adds the medicine to the
    // shopping list when it drops under a day's worth — all in one
    // transaction. An insert here would record the dose and leave the count
    // wrong.
    final result = await _client.rpc<dynamic>(
      'zad_log_pharmacy_dose_atomic',
      params: <String, dynamic>{
        'p_user': userId,
        'p_item': medicineId,
        'p_scheduled_at': scheduledAt?.toUtc().toIso8601String(),
        'p_taken_at': (takenAt ?? DateTime.now()).toUtc().toIso8601String(),
      },
    );

    if (result is! Map) {
      throw StateError('zad_log_pharmacy_dose_atomic answered $result');
    }
    return DoseReceipt.fromJson(Map<String, dynamic>.from(result));
  }

  @override
  Future<void> remove(String id) => _client.from(_items).delete().eq('id', id);
}

/// Reads a timestamptz column.
DateTime? readInstant(Object? value) => switch (value) {
  final String s when s.isNotEmpty => DateTime.parse(s).toUtc(),
  _ => null,
};
