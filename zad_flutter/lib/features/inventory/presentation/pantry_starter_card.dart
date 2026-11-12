/// «أضف أساسيات بيتك بلمسة» — what an empty pantry shows (ZAD_PLAN ١٠.١
/// slice 5).
///
/// It replaces «المخزون فارغ» and its lone camera button: the staples of the
/// account's market as chips, all ticked, and one button that adds them. The
/// receipt stays one quiet link below — the bar's camera is the other way in.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/components/zad_card.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/inventory/domain/starter_essentials.dart';
import 'package:zad/shared/inventory/application/pantry_controller.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/zad_screens.dart';

/// The card.
class PantryStarterCard extends ConsumerStatefulWidget {
  /// Creates the card.
  const new({super.key});

  @override
  ConsumerState<PantryStarterCard> createState() => _StarterState();
}

class _StarterState extends ConsumerState<PantryStarterCard> {
  // Names left out; everything starts ticked, so the common case is one tap.
  final Set<String> _skipped = <String>{};
  bool _adding = false;

  Future<void> _add(List<StarterItem> items) async {
    setState(() => _adding = true);
    final pantry = ref.read(pantryControllerProvider.notifier);
    for (final i in items) {
      await pantry.add(
        itemName: i.name,
        quantity: i.quantity,
        unit: i.unit,
        category: i.category,
      );
    }
    if (mounted) setState(() => _adding = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final all = starterEssentials(ref.watch(accountCountryProvider));
    final chosen = <StarterItem>[
      for (final i in all)
        if (!_skipped.contains(i.name)) i,
    ];
    return Padding(
      padding: const EdgeInsets.all(ZadSpacing.md),
      child: ZadCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Icon(
              Icons.kitchen_rounded,
              size: 40,
              color: ZadColors.green700,
            ),
            const SizedBox(height: ZadSpacing.sm),
            Text(l.pantryStarterTitle, style: ZadType.titleMedium),
            const SizedBox(height: ZadSpacing.xs),
            Text(
              l.pantryStarterBody,
              style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: ZadSpacing.md),
            Wrap(
              spacing: ZadSpacing.sm,
              runSpacing: ZadSpacing.sm,
              children: <Widget>[
                for (final i in all)
                  FilterChip(
                    key: ValueKey<String>('starter-${i.name}'),
                    label: Text(i.name),
                    selected: !_skipped.contains(i.name),
                    onSelected: _adding
                        ? null
                        : (on) => setState(
                            () => on
                                ? _skipped.remove(i.name)
                                : _skipped.add(i.name),
                          ),
                  ),
              ],
            ),
            const SizedBox(height: ZadSpacing.lg),
            FilledButton(
              key: const ValueKey<String>('starter-add'),
              onPressed: chosen.isEmpty || _adding
                  ? null
                  : () => unawaited(_add(chosen)),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: _adding
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l.pantryStarterAdd(chosen.length)),
            ),
            const SizedBox(height: ZadSpacing.xs),
            TextButton.icon(
              onPressed: () => unawaited(ZadScreens.openZadCamera(context)),
              style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
              icon: const Icon(Icons.receipt_long_rounded, size: 18),
              label: Text(l.pantryStarterReceipt),
            ),
          ],
        ),
      ),
    );
  }
}
