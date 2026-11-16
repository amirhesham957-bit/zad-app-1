/// Kotlin's `PharmacyItemCard` inside the world: the name and dose note, the
/// schedule and who it is for, today's pill strip, the stock strip, the badges
/// (expiry or stock, days of supply or "الكمية محتاجة تأكيد") and the actions.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_dialogs.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_strips.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_times_sheet.dart';
import 'package:zad/shared/family/application/family_controller.dart';
import 'package:zad/shared/inventory/application/shopping_controller.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/shared/pharmacy/domain/dose_slot.dart';
import 'package:zad/shared/pharmacy/domain/medicine.dart';
import 'package:zad/shared/worlds/world_card.dart';

/// One of the customer's own medicines.
class MedicineCard extends ConsumerWidget {
  /// Creates the card.
  const new({
    required this.medicine,
    required this.daysToExpiry,
    required this.slots,
    required this.now,
    required this.zone,
    super.key,
  });

  /// The medicine.
  final Medicine medicine;

  /// Days until it expires, negative when it has.
  final int? daysToExpiry;

  /// Today's slots of this medicine.
  final List<DoseSlot> slots;

  /// The present moment.
  final DateTime now;

  /// The account's zone.
  final String zone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(pharmacyControllerProvider.notifier);
    final d = daysToExpiry;
    final expired = d != null && d < 0;
    final expiringSoon = d != null && d >= 0 && d <= 30;
    final supply = medicine.daysOfSupplyLeft;
    final remaining = medicine.remainingQuantity ?? 0;
    final lowStock = medicine.isOutOfStock || (supply ?? 99) <= 5;
    final finished = medicine.isFinishedCourse;
    final status = finished
        ? ZadColors.inkMuted
        : expired || remaining <= 0 || (supply != null && supply <= 3)
        ? ZadColors.terracottaRust
        : lowStock || expiringSoon
        ? ZadColors.mustardOchre
        : ZadColors.green600;
    final member =
        ref
            .watch(familyControllerProvider)
            .family
            ?.members
            .where((m) => m.id == medicine.familyMemberId)
            .firstOrNull
            ?.alias ??
        (medicine.forPerson == null ? null : 'لـ${medicine.forPerson}');
    final badge = finished
        ? 'الكورس خلص ✓'
        : expired
        ? 'منتهي منذ ${-d} يوم'
        : expiringSoon
        ? 'تنتهي خلال $d يوم'
        : 'متبقي $remaining ${medicine.unit ?? ''}'.trim();
    final invalid =
        medicine.hasUnreadableDoseTime || medicine.serverSaysInvalidDoseTime;
    final dosage = medicine.dosage;

    return ZadWorldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: ZadWorldColors.pharmacy.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(
                  dimension: 40,
                  child: Icon(
                    ZadIcons.pharmacy,
                    size: 20,
                    color: ZadWorldColors.pharmacy,
                  ),
                ),
              ),
              const SizedBox(width: ZadSpacing.md),
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
                    if (dosage != null && dosage.trim().isNotEmpty)
                      Text(
                        dosage,
                        style: ZadType.labelSmall.copyWith(
                          color: ZadColors.inkMuted,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () =>
                    unawaited(confirmDeleteMedicine(context, ref, medicine)),
                tooltip: 'حذف',
                style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                icon: Icon(
                  ZadIcons.delete,
                  size: 18,
                  color: ZadColors.terracottaRust,
                ),
              ),
            ],
          ),
          if (medicine.doseTimes.isNotEmpty || member != null)
            Padding(
              padding: const EdgeInsets.only(top: ZadSpacing.xs),
              child: Text(
                <String>[
                  if (medicine.doseTimes.isNotEmpty)
                    medicine.doseTimes.map((t) => t.wireName).join(' · '),
                  ?member,
                ].join('   '),
                style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
              ),
            ),
          if (slots.isNotEmpty) ...<Widget>[
            const SizedBox(height: ZadSpacing.md),
            TodayPillStrip(slots: slots, now: now, zone: zone),
          ],
          if (invalid)
            InkWell(
              onTap: () => unawaited(showDoseTimesSheet(context, medicine)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: ZadSpacing.sm),
                child: Text(
                  'وقت جرعة مش مفهوم — عدّله',
                  style: ZadType.labelSmall.copyWith(
                    color: ZadColors.terracottaRust,
                  ),
                ),
              ),
            )
          else if (medicine.doseTimes.isEmpty && !finished)
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'مالوش مواعيد — مش هفكّرك بيه',
                    style: ZadType.labelSmall.copyWith(
                      color: ZadColors.mustardOchre,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      unawaited(showDoseTimesSheet(context, medicine)),
                  child: const Text('حدد مواعيده'),
                ),
              ],
            ),
          const SizedBox(height: ZadSpacing.md),
          if (!finished) ...<Widget>[
            StockStrip(remaining: remaining),
            const SizedBox(height: ZadSpacing.sm),
          ],
          Wrap(
            spacing: ZadSpacing.sm,
            runSpacing: ZadSpacing.sm,
            children: <Widget>[
              MedicineBadge(text: badge, color: status),
              if (!expired && supply != null)
                MedicineBadge(
                  text: 'يكفي $supply يوم',
                  color: ZadColors.inkMuted,
                )
              else if (!expired &&
                  ((dosage?.isNotEmpty ?? false) ||
                      medicine.doseTimes.isNotEmpty))
                InkWell(
                  onTap: () =>
                      unawaited(showConfirmQuantity(context, ref, medicine)),
                  child: MedicineBadge(
                    text: 'الكمية محتاجة تأكيد',
                    color: ZadColors.mustardOchre,
                  ),
                ),
            ],
          ),
          const SizedBox(height: ZadSpacing.sm),
          Wrap(
            spacing: ZadSpacing.sm,
            runSpacing: ZadSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (remaining > 0 && medicine.doseTimes.isEmpty)
                OutlinedButton(
                  onPressed: () {
                    unawaited(HapticFeedback.mediumImpact());
                    unawaited(controller.takeNow(medicine));
                  },
                  child: const Text('تناول جرعة'),
                ),
              FilledButton.icon(
                onPressed: () => unawaited(showRefill(context, ref, medicine)),
                icon: const Icon(ZadIcons.retry, size: 14),
                label: const Text('تجديد الطلب'),
              ),
              if (lowStock && !finished)
                OutlinedButton.icon(
                  onPressed: () => unawaited(_toShopping(context, ref)),
                  icon: const Icon(ZadIcons.add, size: 14),
                  label: const Text('ضيفه للتسوق'),
                ),
              TextButton(
                onPressed: () =>
                    unawaited(showConfirmQuantity(context, ref, medicine)),
                child: const Text('فاضل قد إيه فعلاً؟'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toShopping(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await ref.read(shoppingControllerProvider.notifier).add(medicine.name);
    messenger?.showSnackBar(
      SnackBar(content: Text('ضفت ${medicine.name} لقايمة التسوق')),
    );
  }
}

/// A small coloured status chip.
class MedicineBadge extends StatelessWidget {
  /// Creates the badge.
  const new({required this.text, required this.color, super.key});

  /// The words.
  final String text;

  /// Its colour.
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(ZadRadii.chip / 2),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ZadSpacing.sm,
        vertical: ZadSpacing.xs,
      ),
      child: Text(
        text,
        style: ZadType.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
