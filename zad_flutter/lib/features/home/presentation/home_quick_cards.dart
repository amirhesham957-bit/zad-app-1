/// Two compact shortcuts at the top of Home: what to cook and today's offers
/// (owner, P1.5b). Each opens its existing screen through [ZadScreens]; the
/// sections grid below keeps its own tiles.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/components/zad_pressable.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/home/presentation/sections_grid.dart';
import 'package:zad/shared/navigation/destinations.dart';
import 'package:zad/shared/navigation/zad_screens.dart';

/// The two cards, side by side.
class HomeQuickCards extends StatelessWidget {
  /// Creates the row.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Row(
      children: <Widget>[
        Expanded(
          child: _QuickCard(
            key: const ValueKey<String>('home-quick-recipes'),
            icon: Icons.soup_kitchen,
            label: l.homeQuickRecipes,
            accent: ZadSectionAccent.emerald,
            onTap: () => ZadScreens.showHouseholdSection(
              context,
              HouseholdSection.recipes,
            ),
          ),
        ),
        const SizedBox(width: ZadSpacing.md),
        Expanded(
          child: _QuickCard(
            key: const ValueKey<String>('home-quick-offers'),
            icon: Icons.card_giftcard,
            label: l.homeQuickOffers,
            accent: ZadSectionAccent.amber,
            onTap: () => ZadScreens.showOffersScreen(context),
          ),
        ),
      ],
    );
  }
}

class _QuickCard extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ZadPressable(
    onPressed: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZadSpacing.md,
        vertical: ZadSpacing.md,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: ZadSpacing.sm),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ZadType.labelLarge.copyWith(
                color: ZadColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
