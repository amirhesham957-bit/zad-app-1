/// عقل زاد: ONE dark world. The painted night scene with the companion on
/// top, the living map of what Zad knows under it (drag it, pick an area with
/// the chips), then calm cards into the staff's notes, memory, the network,
/// the full-screen map, the action log (undo) and the brain's health.
///
/// The map used to be its own screen and the hub a list of six cards; they
/// are one page now. The full-screen map stays one tap away.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_palette.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/brain/application/knowledge_map_controller.dart';
import 'package:zad/features/brain/presentation/agent_action_log_screen.dart';
import 'package:zad/features/brain/presentation/brain_health_screen.dart';
import 'package:zad/features/brain/presentation/brain_world_scene.dart';
import 'package:zad/features/brain/presentation/knowledge_map_screen.dart';
import 'package:zad/features/brain/presentation/memory_graph_screen.dart';
import 'package:zad/features/brain/presentation/memory_screen.dart';
import 'package:zad/features/brain/presentation/staff_screen.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/worlds/world_card.dart';
import 'package:zad/shared/worlds/world_scaffold.dart';
import 'package:zad/shared/worlds/world_tone.dart';
import 'package:zad/shared/worlds/zad_world.dart';

/// Opens the hub.
Future<void> showBrainHub(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute<void>(builder: (_) => const BrainHubScreen()));

/// The brain world.
class BrainHubScreen extends ConsumerWidget {
  /// Creates the hub.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final nodes = ref.watch(knowledgeMapControllerProvider).map.nodeCount;
    final entries = <_Entry>[
      _Entry(
        ZadIcons.assistant,
        l.brainCardStaffTitle,
        l.brainCardStaffBody,
        showStaffScreen,
      ),
      _Entry(
        ZadIcons.memory,
        l.brainCardMemoryTitle,
        l.brainCardMemoryBody,
        showMemoryScreen,
      ),
      _Entry(
        ZadIcons.memoryGraph,
        l.brainCardGraphTitle,
        l.brainCardGraphBody,
        showMemoryGraph,
      ),
      _Entry(
        ZadIcons.knowledgeMap,
        l.brainCardMapTitle,
        l.brainCardMapBody,
        showKnowledgeMap,
      ),
      _Entry(
        ZadIcons.actionLog,
        l.brainCardLogTitle,
        l.brainCardLogBody,
        showAgentActionLog,
      ),
      _Entry(
        ZadIcons.brainHealth,
        l.brainCardHealthTitle,
        l.brainCardHealthBody,
        showBrainHealth,
      ),
    ];

    // The route is a world with no app bar; the Scaffold is the Material the
    // chips and cards splash on.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ZadWorldScaffold(
        world: ZadWorld.brain,
        tone: ZadWorldTone.dark,
        eyebrow: l.brainWorldEyebrow(nodes),
        title: l.worldLabelBrain,
        stateLine: l.brainWorldState,
        scene: BrainWorldScene.new,
        zado: const ZadWorldZado(
          left: 150,
          top: 52,
          size: 130,
          state: CompanionState.focused,
        ),
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              ZadSpacing.gutter,
              ZadSpacing.md,
              ZadSpacing.gutter,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(ZadRadii.cardLarge),
                child: const ColoredBox(
                  color: ZadPalette.sciFiBg,
                  child: SizedBox(
                    height: 520,
                    child: KnowledgeMapBody(embedded: true),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              ZadSpacing.gutter,
              ZadSpacing.lg,
              ZadSpacing.gutter,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Text(
                l.brainCardsTitle,
                style: ZadType.titleMedium.copyWith(
                  color: ZadWorldTone.dark.ink,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              ZadSpacing.gutter,
              ZadSpacing.sm,
              ZadSpacing.gutter,
              0,
            ),
            sliver: SliverList.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: ZadSpacing.md),
              itemBuilder: (context, i) => _EntryCard(entry: entries[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Entry {
  const new(this.icon, this.title, this.subtitle, this.open);

  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function(BuildContext) open;
}

class _EntryCard extends StatelessWidget {
  const new({required this.entry});

  final _Entry entry;

  @override
  Widget build(BuildContext context) => ZadWorldCard(
    onTap: () => entry.open(context),
    child: Row(
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: ZadWorldColors.darkGlow.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(ZadSpacing.md),
            child: Icon(entry.icon, color: ZadWorldColors.darkGlow, size: 22),
          ),
        ),
        const SizedBox(width: ZadSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                entry.title,
                style: ZadType.titleSmall.copyWith(
                  color: ZadWorldTone.dark.ink,
                ),
              ),
              const SizedBox(height: ZadSpacing.xs),
              Text(
                entry.subtitle,
                style: ZadType.bodySmall.copyWith(
                  color: ZadWorldTone.dark.inkMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: ZadSpacing.sm),
        Icon(ZadIcons.forward, size: 18, color: ZadWorldTone.dark.inkMuted),
      ],
    ),
  );
}
