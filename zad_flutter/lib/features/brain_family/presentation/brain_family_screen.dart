/// Kotlin's `BrainFamilyScreen`: عقل زاد and العائلة as two tabs of one
/// gateway. Each tab keeps its main screen and a row of side icons into the
/// screens that used to be scattered — memory, knowledge map, action log
/// and brain health over the intelligence tab; sinking funds and money
/// challenges, achievements and the tasbiha garden over the family tab.
///
/// Adults only: kids mode never reaches it (the kids shell shows the family
/// screen alone, without money), as in Kotlin.
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

/// Opens the gateway on [tab].
Future<void> showBrainFamily(
  BuildContext context, {
  BrainFamilyTab tab = BrainFamilyTab.intelligence,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute<void>(builder: (_) => BrainFamilyScreen(initialTab: tab)),
);

/// The gateway.
class BrainFamilyScreen extends StatefulWidget {
  /// Creates the gateway.
  const new({
    this.initialTab = BrainFamilyTab.intelligence,
    this.embedded = false,
    super.key,
  });

  /// Shown as the shell's عقل زاد tab. Kotlin draws it under the shell
  /// header with no bar of its own: the two tabs on top, then the row of
  /// tools.
  final bool embedded;

  /// The tab it opens on.
  final BrainFamilyTab initialTab;

  @override
  State<BrainFamilyScreen> createState() => _BrainFamilyState();
}

class _BrainFamilyState extends State<BrainFamilyScreen> {
  late BrainFamilyTab _tab = widget.initialTab;

  // A labelled button, not a bare icon (owner, 2026-11-09: «most buttons
  // feel hidden»; emulator, 2026-11-10: four unnamed icons on the bar).
  Widget _side(
    IconData icon,
    String label,
    Future<void> Function(BuildContext) open,
  ) => Padding(
    padding: const EdgeInsetsDirectional.only(end: ZadSpacing.sm),
    child: ActionChip(
      avatar: Icon(icon, size: 18, color: ZadWorld.brain.color),
      label: Text(label),
      labelStyle: ZadType.labelLarge.copyWith(
        color: ZadWorld.brain.color,
        fontWeight: FontWeight.w800,
      ),
      side: BorderSide(color: ZadWorld.brain.color, width: 1.5),
      backgroundColor: ZadColors.surface,
      shape: const StadiumBorder(),
      onPressed: () => unawaited(open(context)),
    ),
  );

  Widget _chip(BrainFamilyTab tab, ZadWorld world, String label) {
    final on = _tab == tab;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: ZadSpacing.sm),
      child: ChoiceChip(
        avatar: ZadArt.icon(world.art, size: 20),
        label: Text(label),
        selected: on,
        showCheckmark: false,
        selectedColor: world.color.withValues(alpha: 0.18),
        side: BorderSide(
          color: on ? world.color : ZadColors.hairline,
          width: 1.5,
        ),
        labelStyle: ZadType.labelLarge.copyWith(
          color: on ? world.color : ZadColors.slate,
          fontWeight: FontWeight.w800,
        ),
        shape: const StadiumBorder(),
        onSelected: (_) => setState(() => _tab = tab),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final intelligence = _tab == BrainFamilyTab.intelligence;
    // The family's own tools (savings funds, achievements, the tasbiha
    // garden) are cards inside the family world now; only the brain's four
    // remain as a row here.
    final side = <Widget>[
      if (intelligence) ...<Widget>[
        _side(
          Icons.psychology,
          'زاد عارف عني إيه',
          ZadScreens.showMemoryScreen,
        ),
        _side(Icons.hub, 'خريطة زاد', ZadScreens.showKnowledgeMap),
        _side(Icons.history, 'سجل تعديلات زاد', ZadScreens.showAgentActionLog),
        _side(Icons.monitor_heart, 'صحة عقل زاد', ZadScreens.showBrainHealth),
      ],
    ];
    return DecoratedBox(
      decoration: BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              // The two destinations are worlds of their own (each paints its
              // own scene and title), so this is only the way between them:
              // a chip in each world's colour.
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
                    _chip(
                      BrainFamilyTab.intelligence,
                      ZadWorld.brain,
                      l.worldLabelBrain,
                    ),
                    _chip(
                      BrainFamilyTab.family,
                      ZadWorld.family,
                      l.worldLabelFamily,
                    ),
                    ...side,
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: intelligence
                      ? ZadSlots.intelligenceScreen(
                          key: const ValueKey<String>('intelligence'),
                          embedded: true,
                        )
                      : ZadSlots.familyScreen(
                          key: const ValueKey<String>('family'),
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
