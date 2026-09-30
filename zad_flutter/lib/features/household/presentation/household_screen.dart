/// The household: pantry, shopping list, pharmacy, recipes.
///
/// One tab with four sections rather than four tabs. The bar already holds
/// four destinations, and the three belong together — a medicine that runs
/// out lands on the same shopping list a carton of milk does.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/shared/navigation/destinations.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/navigation/zad_slots.dart';

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

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(gradient: ZadColors.canvas),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('البيت'),
              actions: <Widget>[
                IconButton(
                  onPressed: () => ZadScreens.showPricesScreen(context),
                  icon: const Icon(ZadIcons.prices),
                  tooltip: 'الأسعار',
                ),
                IconButton(
                  onPressed: () => ZadScreens.showFamilyScreen(context),
                  icon: const Icon(ZadIcons.family),
                  tooltip: 'العيلة',
                ),
              ],
            ),
      // The pantry carries Kotlin's two FABs itself (InventoryScreen).
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
                      HouseholdSection.pantry => ZadSlots.pantryView(),
                      HouseholdSection.shopping => ZadSlots.shoppingListView(),
                      HouseholdSection.pharmacy => ZadSlots.pharmacyView(),
                      HouseholdSection.recipes => ZadSlots.recipesView(),
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
