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
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/features/achievements/presentation/achievements_screen.dart';
import 'package:zad/features/brain/presentation/agent_action_log_screen.dart';
import 'package:zad/features/brain/presentation/brain_health_screen.dart';
import 'package:zad/features/brain/presentation/knowledge_map_screen.dart';
import 'package:zad/features/brain/presentation/memory_screen.dart';
import 'package:zad/features/family/presentation/family_screen.dart';
import 'package:zad/features/intelligence/presentation/intelligence_screen.dart';
import 'package:zad/features/savings/presentation/family_savings_screen.dart';
import 'package:zad/features/tasbiha/presentation/tasbiha_screen.dart';

/// The two tabs.
enum BrainFamilyTab {
  /// عقل زاد.
  intelligence,

  /// العائلة.
  family,
}

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
  const new({this.initialTab = BrainFamilyTab.intelligence, super.key});

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
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(intelligence ? 'عقل زاد' : 'العائلة'),
          actions: intelligence
              ? <Widget>[
                  _side(ZadIcons.memory, 'زاد عارف عني إيه', showMemoryScreen),
                  _side(ZadIcons.knowledgeMap, 'خريطة زاد', showKnowledgeMap),
                  _side(
                    ZadIcons.actionLog,
                    'سجل تعديلات زاد',
                    showAgentActionLog,
                  ),
                  _side(ZadIcons.brainHealth, 'صحة عقل زاد', showBrainHealth),
                ]
              : <Widget>[
                  _side(
                    ZadIcons.savings,
                    'صناديق التجميع',
                    showFamilySavingsScreen,
                  ),
                  _side(
                    ZadIcons.leaderboard,
                    'الإنجازات والرتب',
                    showAchievementsScreen,
                  ),
                  _side(ZadIcons.tree, 'تسبيحة', showTasbihaScreen),
                ],
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
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: intelligence
                    ? const IntelligenceScreen(
                        key: ValueKey<String>('intelligence'),
                        embedded: true,
                      )
                    : const FamilyScreen(key: ValueKey<String>('family')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
