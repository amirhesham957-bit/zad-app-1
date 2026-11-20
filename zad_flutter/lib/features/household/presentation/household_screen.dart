/// The household: pantry, shopping list, pharmacy, recipes.
///
/// One tab with four sections rather than four tabs. The bar already holds
/// four destinations, and the three belong together — a medicine that runs
/// out lands on the same shopping list a carton of milk does.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/navigation/destinations.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/navigation/zad_slots.dart';
import 'package:zad/shared/worlds/art/zad_art.dart';
import 'package:zad/shared/worlds/zad_world.dart';

/// Opens the household on [section], as its own page — how Home's glance
/// cards and the knowledge map reach one section directly.
Future<void> showHouseholdSection(
  BuildContext context,
  HouseholdSection section,
) => Navigator.of(context).push<void>(
  MaterialPageRoute<void>(
    builder: (_) => HouseholdScreen(initialSection: section),
  ),
);

/// The household screen.
class HouseholdScreen extends StatefulWidget {
  /// Creates the screen, open on [initialSection].
  const new({
    this.initialSection = HouseholdSection.pantry,
    this.embedded = false,
    super.key,
  });

  /// Shown as the shell's المخزون tab, under the shell's own header — so
  /// without an app bar of its own, as Kotlin's inventory route has none.
  final bool embedded;

  /// The section showing first — the pantry in the tab; another one when a
  /// screen elsewhere (the knowledge map) opens the household on it.
  final HouseholdSection initialSection;

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  late HouseholdSection _section = widget.initialSection;

  /// Sections opened so far. Each one fetches when it first builds, so a
  /// section is built on first visit rather than all at once — opening
  /// the pantry should not also query every medicine's dose history.
  late final Set<HouseholdSection> _opened = <HouseholdSection>{
    widget.initialSection,
  };

  void _open(HouseholdSection section) => setState(() {
    _section = section;
    _opened.add(section);
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sections = <(HouseholdSection, ZadWorld, String)>[
      (HouseholdSection.pantry, ZadWorld.inv, l.householdPantry),
      (HouseholdSection.shopping, ZadWorld.shop, l.householdShopping),
      (HouseholdSection.pharmacy, ZadWorld.ph, l.householdPharmacy),
      (HouseholdSection.recipes, ZadWorld.chef, l.householdRecipes),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // The pantry carries Kotlin's two FABs itself (InventoryScreen).
        body: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              // The four sections are worlds of their own (each paints its
              // own scene and title), so this is only the way between them:
              // a chip in each world's colour, then the two worlds the
              // household feeds that used to sit in the app bar.
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZadSpacing.sm,
                    vertical: ZadSpacing.xs,
                  ),
                  children: <Widget>[
                    if (!widget.embedded)
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        tooltip: l.worldBack,
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          foregroundColor: ZadColors.ink,
                        ),
                      ),
                    for (final (section, world, label) in sections)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: ZadSpacing.sm,
                        ),
                        child: ChoiceChip(
                          avatar: ZadArt.icon(world.art, size: 20),
                          label: Text(label, maxLines: 1, softWrap: false),
                          selected: _section == section,
                          showCheckmark: false,
                          selectedColor: world.color.withValues(alpha: 0.18),
                          side: BorderSide(
                            color: _section == section
                                ? world.color
                                : ZadColors.hairline,
                            width: 1.5,
                          ),
                          labelStyle: ZadType.labelLarge.copyWith(
                            color: _section == section
                                ? world.color
                                : ZadColors.slate,
                            fontWeight: FontWeight.w800,
                          ),
                          shape: const StadiumBorder(),
                          onSelected: (_) => _open(section),
                        ),
                      ),
                    for (final (world, label, open)
                        in <(ZadWorld, String, OpenScreen)>[
                          (
                            ZadWorld.prices,
                            l.householdPrices,
                            ZadScreens.showPricesScreen,
                          ),
                          (
                            ZadWorld.family,
                            l.householdFamily,
                            (c) => ZadScreens.showFamilyScreen(c),
                          ),
                        ])
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: ZadSpacing.sm,
                        ),
                        child: ActionChip(
                          avatar: ZadArt.icon(world.art, size: 20),
                          label: Text(label, maxLines: 1, softWrap: false),
                          labelStyle: ZadType.labelLarge.copyWith(
                            color: world.color,
                            fontWeight: FontWeight.w800,
                          ),
                          side: BorderSide(color: world.color, width: 1.5),
                          backgroundColor: ZadColors.surface,
                          shape: const StadiumBorder(),
                          onPressed: () => unawaited(open(context)),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                // A section asks for another in place (the pantry's shortages
                // banner opens «التسوق»).
                child: NotificationListener<OpenHouseholdSection>(
                  onNotification: (n) {
                    setState(() {
                      _section = n.section;
                      _opened.add(n.section);
                    });
                    return true;
                  },
                  // IndexedStack, as the shell does: switching sections must
                  // not throw away a scrolled list or re-read Hive.
                  child: IndexedStack(
                    index: _section.index,
                    children: <Widget>[
                      for (final section in HouseholdSection.values)
                        if (_opened.contains(section))
                          switch (section) {
                            HouseholdSection.pantry => ZadSlots.pantryView(),
                            HouseholdSection.shopping =>
                              ZadSlots.shoppingListView(),
                            HouseholdSection.pharmacy =>
                              ZadSlots.pharmacyView(),
                            HouseholdSection.recipes => ZadSlots.recipesView(),
                          }
                        else
                          const SizedBox.shrink(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
