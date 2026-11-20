/// The customer's own tab of the pharmacy world: the overview, today's doses
/// and the medicine cards — or the empty state.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_alarm_hint.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_dose_rows.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_logic.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_medicine_card.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_overview.dart';
import 'package:zad/shared/budget/application/budget_controller.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/shared/pharmacy/domain/dose_slot.dart';
import 'package:zad/shared/pharmacy/domain/medicine.dart';
import 'package:zad/shared/transactions/application/transactions_controller.dart';

/// The own tab.
class PharmacyOwnSection extends ConsumerWidget {
  /// Creates the section.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final view = ref.watch(pharmacyControllerProvider);
    final now = ref.read(nowProvider)();
    final zone = ref.watch(accountTimeZoneProvider);
    final today = DateTime.utc(now.year, now.month, now.day);
    int? daysTo(Medicine m) => m.expiryDate?.difference(today).inDays;

    final medicines = <Medicine>[...view.medicines]
      ..sort((a, b) {
        // Finished courses go last: they are history, not today's care.
        if (a.isFinishedCourse != b.isFinishedCourse) {
          return a.isFinishedCourse ? 1 : -1;
        }
        final da = daysTo(a);
        final db = daysTo(b);
        final ea = da != null && da < 0 ? 0 : 1;
        final eb = db != null && db < 0 ? 0 : 1;
        if (ea != eb) return ea.compareTo(eb);
        return (da ?? 1 << 30).compareTo(db ?? 1 << 30);
      });
    final expiringSoon = <Medicine>[
      for (final m in medicines)
        if ((daysTo(m) ?? -1) >= 0 && daysTo(m)! <= 30) m,
    ];
    final expired = medicines.where((m) => (daysTo(m) ?? 0) < 0).length;
    final low = medicines
        .where(
          (m) =>
              !m.isFinishedCourse &&
              (m.isOutOfStock ||
                  m.isRunningOut ||
                  (m.daysOfSupplyLeft ?? 99) <= 5),
        )
        .length;
    final currency = ref.watch(
      budgetControllerProvider.select((v) => v.snapshot?.currency ?? ''),
    );
    final periodRows = ref.watch(transactionsControllerProvider).rows;
    final cost = pharmacyMonthlyCost(medicines, periodRows);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ExactAlarmHint(
          hasScheduledDoses: medicines.any((m) => m.doseTimes.isNotEmpty),
        ),
        PharmacyOverview(
          adherence: view.adherence,
          costLabel: switch (pharmacyCostKind(medicines, periodRows)) {
            PharmacyCostKind.spending => l.phCostSpending,
            PharmacyCostKind.boxes => l.phCostBoxes,
          },
          costValue: '${pharmacyMoney(cost)} $currency'.trim(),
          total: medicines.length,
          low: low,
          expired: expired,
          expiringSoon: expiringSoon,
          daysTo: daysTo,
        ),
        if (view.today.isNotEmpty || medicines.isNotEmpty) ...<Widget>[
          const SizedBox(height: ZadSpacing.lg),
          Text(
            l.phDosesToday,
            style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
          ),
          const SizedBox(height: ZadSpacing.sm),
          for (final slot in view.today) ...<Widget>[
            OwnDoseRow(slot: slot),
            const SizedBox(height: ZadSpacing.sm),
          ],
          // A heading over nothing read as a broken screen (2026-10-10: three
          // medicines, a cost, and a blank «جرعات النهارده»).
          if (view.today.isEmpty)
            Text(
              medicines.any((m) => m.doseTimes.isNotEmpty)
                  ? l.phNoDosesLeft
                  : l.phNoTimesYet,
              style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
            ),
        ],
        const SizedBox(height: ZadSpacing.lg),
        if (medicines.isEmpty)
          ZadEmptyState(
            icon: ZadIcons.pharmacy,
            title: view.error != null ? l.phLoadFailed : l.phEmptyTitle,
            message: view.error != null ? l.phPullRetry : l.phEmptyGuide,
            tone: view.error != null ? ZadEmptyTone.problem : ZadEmptyTone.calm,
          )
        else ...<Widget>[
          Text(
            l.phMedicines,
            style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
          ),
          const SizedBox(height: ZadSpacing.sm),
          for (final medicine in medicines) ...<Widget>[
            MedicineCard(
              medicine: medicine,
              daysToExpiry: daysTo(medicine),
              slots: <DoseSlot>[
                for (final s in view.today)
                  if (s.medicine.id == medicine.id) s,
              ],
              now: now,
              zone: zone,
            ),
            const SizedBox(height: ZadSpacing.md),
          ],
        ],
      ],
    );
  }
}
