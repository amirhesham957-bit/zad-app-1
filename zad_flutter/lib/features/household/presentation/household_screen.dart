/// The household: pantry, shopping list, pharmacy, recipes.
///
/// One tab with four sections rather than four tabs. The bar already holds
/// four destinations, and the three belong together — a medicine that runs
/// out lands on the same shopping list a carton of milk does.
library;

import 'package:flutter/material.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/features/family/presentation/family_screen.dart';
import 'package:zad/features/inventory/presentation/pantry_view.dart';
import 'package:zad/features/inventory/presentation/shopping_list_view.dart';
import 'package:zad/features/pharmacy/presentation/pharmacy_view.dart';
import 'package:zad/features/prices/presentation/prices_screen.dart';
import 'package:zad/features/recipes/presentation/recipes_view.dart';

/// Which part of the household is showing.
enum HouseholdSection {
  /// What is in the kitchen.
  pantry,

  /// What to buy.
  shopping,

  /// Medicines and doses.
  pharmacy,

  /// What to cook from what is in the kitchen.
  recipes,
}

/// The household screen.
class HouseholdScreen extends StatefulWidget {
  /// Creates the screen, open on [initialSection].
  const new({this.initialSection = HouseholdSection.pantry, super.key});

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

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(gradient: ZadColors.canvas),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('البيت'),
        actions: <Widget>[
          IconButton(
            onPressed: () => showPricesScreen(context),
            icon: const Icon(ZadIcons.prices),
            tooltip: 'الأسعار',
          ),
          IconButton(
            onPressed: () => showFamilyScreen(context),
            icon: const Icon(ZadIcons.family),
            tooltip: 'العيلة',
          ),
        ],
      ),
      floatingActionButton: _section == HouseholdSection.pantry
          ? FloatingActionButton.extended(
              heroTag: 'pantry-add',
              onPressed: () => showAddPantrySheet(context),
              icon: const Icon(ZadIcons.add),
              label: const Text('ضيف صنف'),
              backgroundColor: ZadColors.green800,
              foregroundColor: Colors.white,
            )
          : null,
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.gutter),
            child: SegmentedButton<HouseholdSection>(
              segments: const <ButtonSegment<HouseholdSection>>[
                ButtonSegment<HouseholdSection>(
                  value: HouseholdSection.pantry,
                  label: Text('المخزن'),
                ),
                ButtonSegment<HouseholdSection>(
                  value: HouseholdSection.shopping,
                  label: Text('التسوق'),
                ),
                ButtonSegment<HouseholdSection>(
                  value: HouseholdSection.pharmacy,
                  label: Text('الصيدلية'),
                ),
                ButtonSegment<HouseholdSection>(
                  value: HouseholdSection.recipes,
                  label: Text('وصفات'),
                ),
              ],
              selected: <HouseholdSection>{_section},
              onSelectionChanged: (s) => setState(() {
                _section = s.first;
                _opened.add(s.first);
              }),
              showSelectedIcon: false,
            ),
          ),
          const SizedBox(height: ZadSpacing.sm),
          Expanded(
            // IndexedStack, as the shell does: switching sections must not
            // throw away a scrolled list or re-read Hive every time.
            child: IndexedStack(
              index: _section.index,
              children: <Widget>[
                for (final section in HouseholdSection.values)
                  if (_opened.contains(section))
                    switch (section) {
                      HouseholdSection.pantry => const PantryView(),
                      HouseholdSection.shopping => const ShoppingListView(),
                      HouseholdSection.pharmacy => const PharmacyView(),
                      HouseholdSection.recipes => const RecipesView(),
                    }
                  else
                    const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
