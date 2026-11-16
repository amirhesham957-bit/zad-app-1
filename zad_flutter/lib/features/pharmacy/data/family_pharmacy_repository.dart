/// The family head's writes on a member's medicines.
///
/// Both go through server RPCs (`zad_family_pharmacy_save`,
/// `zad_family_pharmacy_log_dose`) — RLS stays the boundary, the client never
/// writes another account's rows. These are online-only on purpose: an edit
/// to someone else's medicine that waited in an outbox would be applied
/// hours later on a schedule the member may have changed meanwhile, so a
/// failure is said out loud and nothing is queued.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:zad/core/data/providers.dart';

/// Calls one server function. The seam tests replace.
typedef FamilyPharmacyRpc = Future<dynamic> Function(
  String function,
  Map<String, dynamic> params,
);

/// How a head's write ended.
class FamilyPharmacyResult {
  /// Creates a result.
  const new({required this.ok, this.message, this.reason});

  /// It was written.
  final bool ok;

  /// What to tell the customer when it was not — never technical.
  final String? message;

  /// The server's own reason (`not_found`, `duplicate_name`), if it gave one.
  final String? reason;
}

/// What the head's screen says for each refusal.
const String kNotFamilyHeadMessage =
    'بس رب الأسرة يقدر يعدّل أدوية حد من العيلة.';

/// Said when the call could not reach the server.
const String kFamilyPharmacyOfflineMessage =
    'مفيش نت دلوقتي — ما اتحفظش حاجة. جرّب تاني لما يرجع.';

String _reasonMessage(String? reason) => switch (reason) {
  'not_found' => 'الدوا ده مش موجود عند العضو دلوقتي — حدّث الصفحة.',
  'duplicate_name' => 'العضو عنده دوا بنفس الاسم ده.',
  _ => 'السيرفر رفض الحفظ. جرّب تاني.',
};

/// The head's writes.
class FamilyPharmacyRepository {
  /// Creates the repository over the given `rpc`.
  const new(this._rpc);

  final FamilyPharmacyRpc _rpc;

  /// Adds (`item` null) or edits a medicine of [target].
  Future<FamilyPharmacyResult> save({
    required String target,
    required String name,
    required String unit,
    required int dailyDoseCount,
    required String doseTimes,
    required double unitsPerDose,
    required int remainingQuantity,
    String? item,
    String? dosage,
    DateTime? expiryDate,
  }) => _call('zad_family_pharmacy_save', <String, dynamic>{
    'p_target': target,
    'p_item': item,
    'p_name': name.trim(),
    'p_dosage': dosage?.trim() ?? '',
    'p_unit': unit,
    'p_daily_dose_count': dailyDoseCount,
    'p_dose_times': doseTimes,
    'p_units_per_dose': unitsPerDose,
    'p_remaining_quantity': remainingQuantity,
    'p_expiry_date': expiryDate == null ? null : _date(expiryDate),
  });

  /// «خدها»: the head marks `member`'s dose as taken.
  Future<FamilyPharmacyResult> logDose({
    required String target,
    required String item,
    required DateTime scheduledAt,
    required DateTime takenAt,
  }) => _call('zad_family_pharmacy_log_dose', <String, dynamic>{
    'p_target': target,
    'p_item': item,
    'p_scheduled_at': scheduledAt.toUtc().toIso8601String(),
    'p_taken_at': takenAt.toUtc().toIso8601String(),
  });

  Future<FamilyPharmacyResult> _call(
    String function,
    Map<String, dynamic> params,
  ) async {
    try {
      final answer = await _rpc(function, params);
      if (answer is Map && answer['ok'] == false) {
        final reason = answer['reason'] as String?;
        return FamilyPharmacyResult(
          ok: false,
          reason: reason,
          message: _reasonMessage(reason),
        );
      }
      return const FamilyPharmacyResult(ok: true);
    } on PostgrestException catch (error) {
      if (error.code == '42501' || error.message.contains('not_family_head')) {
        return const FamilyPharmacyResult(
          ok: false,
          reason: 'not_family_head',
          message: kNotFamilyHeadMessage,
        );
      }
      return FamilyPharmacyResult(
        ok: false,
        message: _reasonMessage(null),
        reason: error.code,
      );
    } on Object {
      // No route to the server (offline, a timeout, a dropped socket).
      return const FamilyPharmacyResult(
        ok: false,
        reason: 'offline',
        message: kFamilyPharmacyOfflineMessage,
      );
    }
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// The head's writes, over the signed-in client.
final familyPharmacyRepositoryProvider = Provider<FamilyPharmacyRepository>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return FamilyPharmacyRepository(
    (fn, params) => client.rpc<dynamic>(fn, params: params),
  );
});
