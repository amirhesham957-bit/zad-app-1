/// The household: pantry, shopping list, pharmacy.
///
/// One tab with three sections rather than three tabs. The bar already holds
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

/// Which part of the household is showing.
enum HouseholdSection {
  /// What is in the kitchen.
  pantry,

  /// What to buy.
  shopping,

  /// Medicines and doses.
  pharmacy,
}

/// The household screen.
class HouseholdScreen extends StatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  HouseholdSection _section = HouseholdSection.pantry;

  /// Sections opened so far. Each one fetches when it first builds, so a
  /// section is built on first visit rather than all three at once — opening
  /// the pantry should not also query every medicine's dose history.
  final Set<HouseholdSection> _opened = <HouseholdSection>{
    HouseholdSection.pantry,
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
