/// A dose as a row: its clock, the medicine, where it stands, and what can be
/// done about it. The customer's own rows carry «خدته» and «بعدين»; the head's
/// rows for a member carry «خدها».
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_logic.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/pharmacy/application/pharmacy_controller.dart';
import 'package:zad/shared/pharmacy/domain/dose_slot.dart';
import 'package:zad/shared/worlds/world_card.dart';

/// The layout every dose row shares.
class DoseTile extends ConsumerWidget {
  /// Creates the tile.
  const new({
    required this.slot,
    required this.status,
    required this.accent,
    this.trailing = const <Widget>[],
    super.key,
  });

  /// The dose.
  final DoseSlot slot;

  /// What it says under the name.
  final String status;

  /// The status colour.
  final Color accent;

  /// Buttons at the end.
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ZadWorldCard(
    child: Row(
      children: <Widget>[
        SizedBox(
          width: 56,
          child: Text(
            // The account's civil time, not the device's. A customer
            // travelling sees the same "08:00" the server reminds them at.
            doseClock(slot, ref.read(accountTimeZoneProvider)),
            style: ZadType.figure(16).copyWith(color: ZadColors.ink),
          ),
        ),
        const SizedBox(width: ZadSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(slot.medicine.name, style: ZadType.titleSmall),
              Text(status, style: ZadType.labelSmall.copyWith(color: accent)),
            ],
          ),
        ),
        ...trailing,
      ],
    ),
  );
}

/// One of the customer's own doses today.
class OwnDoseRow extends ConsumerWidget {
  /// Creates the row.
  const new({required this.slot, super.key});

  /// The dose.
  final DoseSlot slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(pharmacyControllerProvider.notifier);
    final state = slot.stateAt(ref.read(nowProvider)());
    final snoozed = controller.isSnoozed(slot);
    final (accent, status) = switch (state) {
      DoseState.taken => (ZadColors.green600, 'اتاخدت'),
      DoseState.due => (ZadColors.mustardOchre, 'وقتها دلوقتي'),
      DoseState.missed => (ZadColors.terracottaRust, 'فاتت'),
      DoseState.upcoming => (ZadColors.inkMuted, 'جاية'),
    };
    return DoseTile(
      slot: slot,
      accent: accent,
      status: snoozed ? 'اتأجلت شوية' : status,
      trailing: <Widget>[
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
            // The theme's buttons are full width; in a row that is infinite.
            style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text('خدته'),
          ),
        ] else if (state == DoseState.taken)
          const Icon(ZadIcons.synced, color: ZadColors.green600),
      ],
    );
  }
}
