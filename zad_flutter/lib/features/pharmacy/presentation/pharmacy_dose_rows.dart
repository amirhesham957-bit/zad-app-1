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
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/core/l10n/l10n.dart';
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
  Widget build(BuildContext context, WidgetRef ref) {
    final taken = slot.isTaken;
    final fg = taken ? Colors.white : ZadColors.ink;
    final row = Row(
      children: <Widget>[
        SizedBox(
          width: 56,
          child: Text(
            // The account's civil time, not the device's. A customer
            // travelling sees the same "08:00" the server reminds them at.
            doseClock(slot, ref.read(accountTimeZoneProvider)),
            style: ZadType.figure(16).copyWith(color: fg),
          ),
        ),
        const SizedBox(width: ZadSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                slot.medicine.name,
                style: ZadType.titleSmall.copyWith(color: fg),
              ),
              Text(
                status,
                style: ZadType.labelSmall.copyWith(
                  color: taken ? Colors.white70 : accent,
                ),
              ),
            ],
          ),
        ),
        ...trailing,
      ],
    );
    // The preview's dose tile: taken is the strong violet, due has a gold
    // ring, the rest are white with a lavender edge.
    if (taken) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ZadRadii.cardLarge),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: <Color>[Color(0xFF6B5FC7), ZadWorldColors.pharmacy],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(ZadSpacing.lg),
          child: row,
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ZadRadii.cardLarge),
        border: Border.all(
          color: accent == ZadColors.mustardOchre
              ? ZadColors.mustardOchre
              : const Color(0xFFD9D3F5),
          width: accent == ZadColors.mustardOchre ? 3 : 2,
        ),
      ),
      child: ZadWorldCard(child: row),
    );
  }
}

/// One of the customer's own doses today.
class OwnDoseRow extends ConsumerWidget {
  /// Creates the row.
  const new({required this.slot, super.key});

  /// The dose.
  final DoseSlot slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final controller = ref.read(pharmacyControllerProvider.notifier);
    final state = slot.stateAt(ref.read(nowProvider)());
    final snoozed = controller.isSnoozed(slot);
    final (accent, status) = switch (state) {
      DoseState.taken => (ZadColors.green600, l.phDoseTaken),
      DoseState.due => (ZadColors.mustardOchre, l.phDoseDue),
      DoseState.missed => (ZadColors.terracottaRust, l.phDoseMissed),
      DoseState.upcoming => (ZadColors.inkMuted, l.phDoseUpcoming),
    };
    return DoseTile(
      slot: slot,
      accent: accent,
      status: snoozed ? l.phDoseSnoozed : status,
      trailing: <Widget>[
        if (state == DoseState.due || state == DoseState.missed) ...<Widget>[
          if (!snoozed)
            TextButton(
              onPressed: () => unawaited(controller.snooze(slot)),
              child: Text(l.phSnooze),
            ),
          FilledButton(
            onPressed: () {
              unawaited(HapticFeedback.mediumImpact());
              unawaited(controller.take(slot));
            },
            // The theme's buttons are full width; in a row that is infinite.
            style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            child: Text(l.phTake),
          ),
        ] else if (state == DoseState.taken)
          const Icon(ZadIcons.synced, color: Colors.white),
      ],
    );
  }
}
