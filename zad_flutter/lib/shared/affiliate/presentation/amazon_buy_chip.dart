/// «من أمازون»: a compact pill that opens a tagged search for an item in the
/// account's own store, so a missing item is one tap from being bought and
/// the commission is kept (owner, 2026-11-15).
///
/// Nothing renders for a child (kids mode) or in broke mode — the same gating
/// as the home strip.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/affiliate/data/affiliate_repository.dart';
import 'package:zad/shared/kids/application/kids_mode_controller.dart';
import 'package:zad/shared/modes/application/modes_controller.dart';

/// Whether buy links may show at all now. Unreadable kids or broke state
/// (a screen opened without the device store, as many tests do) hides them:
/// a child must never see a buy link by accident.
final amazonChipsAllowedProvider = Provider<bool>((ref) {
  try {
    if (ref.watch(kidsModeActiveProvider)) return false;
    return ref.watch(modesControllerProvider.select((v) => v.broke == null));
  } on Object {
    return false;
  }
});

/// The pill for [itemName]; [sourceScreen] is recorded with the click.
class AmazonBuyChip extends ConsumerWidget {
  /// Creates the chip.
  const new({required this.itemName, required this.sourceScreen, super.key});

  /// What to search for.
  final String itemName;

  /// Where the chip sits, e.g. `shopping_row`.
  final String sourceScreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(amazonChipsAllowedProvider) || itemName.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final label = context.l10n.amazonBuyChipLabel(itemName.trim());
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: ZadColors.mint50,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => unawaited(
            openAmazonSearch(ref, itemName.trim(), sourceScreen: sourceScreen),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kZadMinTapTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.md),
              // Scales down in a column too narrow for it (a pantry card on
              // a 320dp phone) rather than overflowing.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      ZadIcons.shopping,
                      size: 16,
                      color: ZadColors.green700,
                    ),
                    const SizedBox(width: ZadSpacing.xs),
                    Text(
                      context.l10n.amazonBuyChip,
                      style: ZadType.labelMedium.copyWith(
                        color: ZadColors.green700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The once-per-section line that says the chips are affiliate links.
class AmazonChipsNote extends ConsumerWidget {
  /// Creates the note.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(amazonChipsAllowedProvider)) return const SizedBox.shrink();
    return Text(
      context.l10n.amazonChipsNote,
      style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
    );
  }
}
