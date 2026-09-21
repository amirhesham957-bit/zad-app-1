/// Today's doses, and what is being tracked.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/components/zad_card.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/features/pharmacy/domain/dose_slot.dart';
import 'package:zad/features/pharmacy/domain/medicine.dart';

/// The pharmacy.
class PharmacyView extends ConsumerWidget {
  /// Creates the view.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(pharmacyControllerProvider);
    final controller = ref.read(pharmacyControllerProvider.notifier);

    if (view.isEmpty) {
      return RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            const SizedBox(height: ZadSpacing.xxl),
            ZadEmptyState(
              icon: ZadIcons.pharmacy,
              title: view.error != null
                  ? 'مقدرتش أجيب الأدوية'
                  : 'مفيش أدوية متسجلة',
              message: view.error != null
                  ? 'اسحب لتحت نجرب تاني.'
                  : 'قول لزاد في الشات: "باخد كونكور قرص الصبح وبالليل" '
                        'وهو يسجّله بمواعيده.',
              tone: view.error != null
                  ? ZadEmptyTone.problem
                  : ZadEmptyTone.calm,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(ZadSpacing.gutter),
        children: <Widget>[
          if (view.today.isNotEmpty) ...<Widget>[
            Text(
              'جرعات النهارده',
              style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: ZadSpacing.sm),
            for (final slot in view.today) ...<Widget>[
              _DoseRow(slot: slot),
              const SizedBox(height: ZadSpacing.sm),
            ],
            const SizedBox(height: ZadSpacing.lg),
          ],
          Text(
            'الأدوية',
            style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
          ),
          const SizedBox(height: ZadSpacing.sm),
          for (final medicine in view.medicines) ...<Widget>[
            _MedicineRow(medicine: medicine),
            const SizedBox(height: ZadSpacing.sm),
          ],
          const SizedBox(height: 88),
        ],
      ),
    );
  }
}

class _DoseRow extends ConsumerWidget {
  const new({required this.slot});

  final DoseSlot slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(pharmacyControllerProvider.notifier);
    final now = ref.read(nowProvider)();
    final state = slot.stateAt(now);
    final snoozed = controller.isSnoozed(slot);

    final (accent, status) = switch (state) {
      DoseState.taken => (ZadColors.green600, 'اتاخدت'),
      DoseState.due => (ZadColors.mustardOchre, 'وقتها دلوقتي'),
      DoseState.missed => (ZadColors.terracottaRust, 'فاتت'),
      DoseState.upcoming => (ZadColors.inkMuted, 'جاية'),
    };

    return ZadCard(
      padding: const EdgeInsets.all(ZadSpacing.md),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 56,
            child: Text(
              // The account's civil time, not the device's. A customer
              // travelling sees the same "08:00" the server reminds them at.
              _clock(slot.scheduledAt, ref.read(accountTimeZoneProvider)),
              style: ZadType.figure(16).copyWith(color: ZadColors.ink),
            ),
          ),
          const SizedBox(width: ZadSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(slot.medicine.name, style: ZadType.titleSmall),
                Text(
                  snoozed ? 'اتأجلت شوية' : status,
                  style: ZadType.labelSmall.copyWith(color: accent),
                ),
              ],
            ),
          ),
          if (state == DoseState.due || state == DoseState.missed) ...<Widget>[
            if (!snoozed)
              TextButton(
                onPressed: () => unawaited(controller.snooze(slot)),
                child: const Text('بعدين'),
              ),
            FilledButton(
              onPressed: () {
                unawaited(HapticFeedback.mediumImpact());
                unawaited(controller.take(slot));
              },
              child: const Text('خدته'),
            ),
          ] else if (state == DoseState.taken)
            const Icon(ZadIcons.synced, color: ZadColors.green600),
        ],
      ),
    );
  }

  static String _clock(DateTime instant, String zone) {
    final local = tz.TZDateTime.from(instant.toUtc(), tz.getLocation(zone));
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _MedicineRow extends StatelessWidget {
  const new({required this.medicine});

  final Medicine medicine;

  @override
  Widget build(BuildContext context) {
    final notes = <String>[
      if (medicine.dosage case final d? when d.isNotEmpty) d,
      if (medicine.doseTimes.isNotEmpty)
        medicine.doseTimes.map((t) => t.wireName).join('، '),
      if (medicine.remainingQuantity case final r?)
        'باقي $r ${medicine.unit ?? ''}'.trim(),
    ];

    // The two reasons a medicine can be silent on the server, said out loud
    // rather than left for the customer to discover by missing a reminder.
    final warning =
        medicine.hasUnreadableDoseTime || medicine.serverSaysInvalidDoseTime
        ? 'في ميعاد مكتوب غلط — مش هتوصلك تذكيرات لحد ما يتصلح.'
        : medicine.isOutOfStock
        ? 'خلص — مش هتوصلك تذكيرات.'
        : medicine.isRunningOut
        ? 'باقي أقل من يوم.'
        : null;

    return ZadCard(
      padding: const EdgeInsets.all(ZadSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(medicine.name, style: ZadType.titleSmall),
          if (notes.isNotEmpty)
            Text(
              notes.join(' · '),
              style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
            ),
          if (warning != null) ...<Widget>[
            const SizedBox(height: ZadSpacing.xs),
            Text(
              warning,
              style: ZadType.labelSmall.copyWith(
                color: ZadColors.terracottaRust,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
