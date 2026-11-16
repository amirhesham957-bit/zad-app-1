/// What the family section reads and writes: which tab is open, who the other
/// members are, whether the customer is the head, what the server lets them
/// read, the doses the head marked this session, and the head's save.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/features/pharmacy/data/family_pharmacy_repository.dart';
import 'package:zad/features/pharmacy/presentation/medicine_draft.dart';
import 'package:zad/shared/family/application/family_controller.dart';
import 'package:zad/shared/family/domain/family.dart';
import 'package:zad/shared/pharmacy/domain/dose_slot.dart';
import 'package:zad/shared/pharmacy/domain/medicine.dart';

/// Which member's tab is open; null is the customer's own.
class PharmacySelectedMember extends Notifier<String?> {
  @override
  String? build() => null;

  /// Opens [userId]'s tab (null: the customer's own).
  // ignore: use_setters_to_change_properties, a setter cannot take null.
  void select(String? userId) => state = userId;
}

/// The open tab.
final pharmacySelectedMemberProvider =
    NotifierProvider<PharmacySelectedMember, String?>(
      PharmacySelectedMember.new,
    );

/// The other members of the customer's family, none when there is no family.
final Provider<List<FamilyMember>> pharmacyOtherMembersProvider =
    Provider<List<FamilyMember>>((ref) {
      final view = ref.watch(familyControllerProvider);
      final family = view.family;
      if (family == null || family.members.length < 2) {
        return const <FamilyMember>[];
      }
      return <FamilyMember>[
        for (final m in family.members)
          if (m.userId != view.userId) m,
      ];
    });

/// Whether the customer is the family head.
final Provider<bool> isFamilyHeadProvider = Provider<bool>(
  (ref) => ref.watch(familyControllerProvider).isAdmin,
);

/// Every pharmacy row RLS lets this account read.
final FutureProvider<List<Medicine>> familyPharmacyItemsProvider =
    FutureProvider.autoDispose<List<Medicine>>((ref) async {
      final rows = await ref
          .watch(supabaseClientProvider)
          .from('zad_pharmacy_items')
          .select();
      return <Medicine>[
        for (final r in rows) Medicine.fromJson(Map<String, dynamic>.from(r)),
      ];
    });

/// Doses the head marked in this session, as `itemId:scheduledAt`.
class FamilyTakenDoses extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  /// Remembers [slot] as taken.
  void mark(DoseSlot slot) => state = <String>{...state, keyOf(slot)};

  /// The key a slot is remembered under.
  static String keyOf(DoseSlot s) =>
      '${s.medicine.id}:${s.scheduledAt.toIso8601String()}';
}

/// What the head marked taken this session.
final familyTakenDosesProvider =
    NotifierProvider<FamilyTakenDoses, Set<String>>(FamilyTakenDoses.new);

/// The head saves a member's medicine; answers a message or null.
Future<String?> saveMemberMedicine(
  WidgetRef ref, {
  required String target,
  required MedicineDraft draft,
  Medicine? item,
}) async {
  final result = await ref
      .read(familyPharmacyRepositoryProvider)
      .save(
        target: target,
        item: item?.id,
        name: draft.name,
        dosage: draft.dosage,
        unit: draft.unit,
        dailyDoseCount: draft.dailyDoseCount,
        doseTimes: draft.doseTimes,
        unitsPerDose: draft.unitsPerDose,
        remainingQuantity: draft.quantity,
        expiryDate: draft.expiry,
      );
  if (result.ok) ref.invalidate(familyPharmacyItemsProvider);
  return result.ok ? null : result.message;
}
