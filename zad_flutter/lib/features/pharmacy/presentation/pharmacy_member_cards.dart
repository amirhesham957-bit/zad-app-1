/// A member's rows in the family section: a dose (the head can mark it
/// «خدها») and a medicine card (the head can edit it).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/pharmacy/data/family_pharmacy_repository.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_dose_rows.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_family_state.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_form_openers.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_logic.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_medicine_card.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_strips.dart';
import 'package:zad/shared/family/domain/family.dart';
import 'package:zad/shared/pharmacy/domain/dose_slot.dart';
import 'package:zad/shared/pharmacy/domain/medicine.dart';
import 'package:zad/shared/worlds/world_card.dart';

/// One of a member's doses today.
class MemberDoseRow extends ConsumerWidget {
  /// Creates the row.
  const new({
    required this.slot,
    required this.member,
    required this.head,
    required this.taken,
    required this.now,
    super.key,
  });

  /// The dose.
  final DoseSlot slot;

  /// Whose it is.
  final FamilyMember member;

  /// The customer is the head.
  final bool head;

  /// The head marked it taken this session.
  final bool taken;

  /// The present moment.
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = slot.scheduledAt.isAfter(now.toUtc());
    final canTake =
        head &&
        !taken &&
        slot.scheduledAt.isBefore(now.toUtc().add(const Duration(hours: 1)));
    final (accent, status) = taken
        ? (ZadColors.green600, 'اتاخدت')
        : upcoming
        ? (ZadColors.inkMuted, 'جاية')
        : (ZadColors.inkMuted, 'الميعاد عدّى');
    return DoseTile(
      slot: slot,
      accent: accent,
      status: status,
      trailing: <Widget>[
        if (taken)
          const Icon(ZadIcons.synced, color: ZadColors.green600)
        else if (canTake)
          FilledButton(
            onPressed: () => unawaited(_take(context, ref)),
            // The theme's buttons are full width; in a row that is infinite.
            style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text('خدها'),
          ),
      ],
    );
  }

  Future<void> _take(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await ref
        .read(familyPharmacyRepositoryProvider)
        .logDose(
          target: member.userId,
          item: slot.medicine.id,
          scheduledAt: slot.scheduledAt,
          takenAt: ref.read(nowProvider)(),
        );
    if (result.ok) {
      ref.read(familyTakenDosesProvider.notifier).mark(slot);
      ref.invalidate(familyPharmacyItemsProvider);
    } else {
      messenger?.showSnackBar(SnackBar(content: Text(result.message ?? '')));
    }
  }
}

/// One of a member's medicines.
class MemberMedicineCard extends ConsumerWidget {
  /// Creates the card.
  const new({
    required this.medicine,
    required this.member,
    required this.head,
    required this.slots,
    required this.now,
    required this.zone,
    super.key,
  });

  /// The medicine.
  final Medicine medicine;

  /// Whose it is.
  final FamilyMember member;

  /// The customer is the head.
  final bool head;

  /// Today's slots of this medicine.
  final List<DoseSlot> slots;

  /// The present moment.
  final DateTime now;

  /// The account's zone.
  final String zone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = sanitizeDosageNote(medicine.dosage);
    // Kotlin's `isLowStock`: out, or five days or less of supply.
    final low =
        (medicine.remainingQuantity ?? 1) <= 0 ||
        (medicine.daysOfSupplyLeft ?? 99) <= 5;
    final color = low ? ZadColors.terracottaRust : ZadColors.green600;
    return ZadWorldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      medicine.name,
                      style: ZadType.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (note != null)
                      Text(
                        note,
                        style: ZadType.labelSmall.copyWith(
                          color: ZadColors.inkMuted,
                        ),
                      ),
                  ],
                ),
              ),
              MedicineBadge(
                text:
                    '${medicine.remainingQuantity ?? 0} ${medicine.unit ?? ''}'
                        .trim(),
                color: color,
              ),
              if (head)
                IconButton(
                  tooltip: 'تعديل',
                  style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                  onPressed: () => unawaited(
                    showMedicineFormSheet(
                      context,
                      own: false,
                      initial: medicine,
                      title: 'تعديل ${medicine.name}',
                      onSave: (d) => saveMemberMedicine(
                        ref,
                        target: member.userId,
                        item: medicine,
                        draft: d,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
            ],
          ),
          if (slots.isNotEmpty) ...<Widget>[
            const SizedBox(height: ZadSpacing.md),
            TodayPillStrip(
              slots: slots,
              now: now,
              zone: zone,
              knowsPast: false,
            ),
          ],
          const SizedBox(height: ZadSpacing.md),
          StockStrip(remaining: medicine.remainingQuantity ?? 0),
        ],
      ),
    );
  }
}
