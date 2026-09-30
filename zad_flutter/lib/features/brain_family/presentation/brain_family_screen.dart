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
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/shared/navigation/destinations.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/navigation/zad_slots.dart';

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
  /// side icons, end-aligned.
  final bool embedded;

  /// The tab it opens on.
  final BrainFamilyTab initialTab;

  @override
  State<BrainFamilyScreen> createState() => _BrainFamilyState();
}

class _BrainFamilyState extends State<BrainFamilyScreen> {
  late BrainFamilyTab _tab = widget.initialTab;

  Widget _side(
    IconData icon,
    String label,
    Future<void> Function(BuildContext) open,
  ) => IconButton(
    tooltip: label,
    onPressed: () => unawaited(open(context)),
    icon: Icon(icon, size: 20, color: ZadColors.inkMuted),
  );

  @override
  Widget build(BuildContext context) {
    final intelligence = _tab == BrainFamilyTab.intelligence;
    final side = intelligence
        ? <Widget>[
            _side(
              Icons.psychology,
              'زاد عارف عني إيه',
              ZadScreens.showMemoryScreen,
            ),
            _side(Icons.hub, 'خريطة زاد', ZadScreens.showKnowledgeMap),
            _side(
              Icons.history,
              'سجل تعديلات زاد',
              ZadScreens.showAgentActionLog,
            ),
            _side(
              Icons.monitor_heart,
              'صحة عقل زاد',
              ZadScreens.showBrainHealth,
            ),
          ]
        : <Widget>[
            _side(
              ZadIcons.savings,
              'صناديق التجميع',
              ZadScreens.showFamilySavingsScreen,
            ),
            _side(
              ZadIcons.leaderboard,
              'الإنجازات والرتب',
              ZadScreens.showAchievementsScreen,
            ),
            _side(ZadIcons.tree, 'تسبيحة', ZadScreens.showTasbihaScreen),
          ];
    return DecoratedBox(
      decoration: BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: widget.embedded
            ? null
            : AppBar(
                title: Text(intelligence ? 'عقل زاد' : 'العائلة'),
                actions: side,
              ),
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZadSpacing.lg,
                vertical: ZadSpacing.xs,
              ),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<BrainFamilyTab>(
                  showSelectedIcon: false,
                  segments: const <ButtonSegment<BrainFamilyTab>>[
                    ButtonSegment<BrainFamilyTab>(
                      value: BrainFamilyTab.intelligence,
                      icon: Icon(ZadIcons.brain, size: 18),
                      label: Text('عقل زاد'),
                    ),
                    ButtonSegment<BrainFamilyTab>(
                      value: BrainFamilyTab.family,
                      icon: Icon(ZadIcons.family, size: 18),
                      label: Text('العائلة'),
                    ),
                  ],
                  selected: <BrainFamilyTab>{_tab},
                  onSelectionChanged: (s) => setState(() => _tab = s.first),
                ),
              ),
            ),
            if (widget.embedded)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: side,
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
    );
  }
}
