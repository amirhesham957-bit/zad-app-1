/// أشجار العيلة (the leaderboard, shareable as an image) and التحديات.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/tasbiha/presentation/leaderboard_share.dart';
import 'package:zad/features/tasbiha/presentation/tasbiha_dialogs.dart';
import 'package:zad/shared/family/application/family_controller.dart';
import 'package:zad/shared/tasbiha/application/tasbiha_controller.dart';
import 'package:zad/shared/tasbiha/domain/tasbiha.dart';
import 'package:zad/shared/worlds/art/art.dart';
import 'package:zad/shared/worlds/world_card.dart';

/// The family leaderboard as the body of a world.
class TasbihaFamilyTab extends ConsumerWidget {
  /// Creates the tab.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final family = ref.watch(familyControllerProvider).family;
    final trees = ref.watch(
      tasbihaControllerProvider.select((v) => v.familyTrees),
    );
    final gardens = family == null
        ? const <MemberGarden>[]
        : memberGardens(family, trees);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l.tasLeaderboard,
                style: ZadType.titleLarge.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (gardens.isNotEmpty)
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () => unawaited(shareLeaderboard(gardens)),
                icon: const Icon(ZadIcons.share, size: 18),
                label: Text(l.tasShare),
              ),
          ],
        ),
        const SizedBox(height: ZadSpacing.md),
        if (gardens.isEmpty)
          ZadWorldCard(
            child: ZadEmptyState(
              icon: ZadIcons.tree,
              title: l.tasNoTreesTitle,
              message: l.tasNoTreesMsg,
            ),
          )
        else
          for (final (i, g) in gardens.indexed) ...<Widget>[
            _MemberCard(garden: g, rank: i + 1),
            const SizedBox(height: ZadSpacing.sm),
          ],
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  const new({required this.garden, required this.rank});

  final MemberGarden garden;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final alias = garden.member.alias;
    final streak = longestStreak(garden.trees);
    return ZadWorldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      (rank <= 3
                              ? const Color(0xFFF5B93A)
                              : ZadWorldColors.tasbih)
                          .withValues(alpha: 0.22),
                ),
                child: Text(
                  '$rank',
                  style: ZadType.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: ZadSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      alias,
                      style: ZadType.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      l.tasMemberTrees(garden.trees.length, garden.matureTrees),
                      style: ZadType.bodySmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                    if (streak > 0)
                      Row(
                        children: <Widget>[
                          ZadArt.icon(ZadIconArt.flame, size: 16),
                          const SizedBox(width: ZadSpacing.xs),
                          Text(
                            l.tasStreakDays(streak),
                            style: ZadType.bodySmall.copyWith(
                              color: ZadWorldColors.tasbih,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    '${garden.totalScore}',
                    style: ZadType.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: ZadWorldColors.tasbih,
                    ),
                  ),
                  Text(
                    l.tasUnit,
                    style: ZadType.labelSmall.copyWith(
                      color: ZadColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (garden.trees.isNotEmpty) ...<Widget>[
            const SizedBox(height: ZadSpacing.md),
            Wrap(
              spacing: ZadSpacing.sm,
              runSpacing: ZadSpacing.sm,
              children: <Widget>[
                for (final t in garden.trees.take(5)) _MiniTree(tree: t),
                if (garden.trees.length > 5)
                  Text(
                    '+${garden.trees.length - 5}',
                    style: ZadType.labelMedium.copyWith(
                      color: ZadWorldColors.tasbih,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _short(String s) => s.length > 8 ? s.substring(0, 8) : s;

class _MiniTree extends StatelessWidget {
  const new({required this.tree});

  final GardenTree tree;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: ZadColors.surfaceLow,
      borderRadius: BorderRadius.circular(ZadRadii.chip),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ZadSpacing.sm,
        vertical: ZadSpacing.xs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ZadArt.icon(ZadIconArt.tree, size: 20),
          const SizedBox(width: ZadSpacing.xs),
          Text(
            '${_short(tree.treeName)} ${tree.score}',
            maxLines: 1,
            style: ZadType.labelSmall,
          ),
        ],
      ),
    ),
  );
}

/// The family's challenges as the body of a world.
class TasbihaChallengesTab extends ConsumerWidget {
  /// Creates the tab.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isAdmin = ref.watch(familyControllerProvider).isAdmin;
    final view = ref.watch(tasbihaControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l.tasChallengesTitle,
                style: ZadType.titleLarge.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (isAdmin)
              IconButton.filledTonal(
                tooltip: l.tasNewChallenge,
                style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: () =>
                    unawaited(showCreateChallengeDialog(context, ref)),
                icon: const Icon(ZadIcons.add),
              ),
          ],
        ),
        Text(
          l.tasChallengesTagline,
          style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
        ),
        const SizedBox(height: ZadSpacing.md),
        if (view.challenges.isEmpty)
          ZadWorldCard(
            child: ZadEmptyState(
              icon: Icons.track_changes,
              title: l.tasNoChallengesTitle,
              message: isAdmin
                  ? l.tasNoChallengesAdmin
                  : l.tasNoChallengesMember,
            ),
          )
        else
          for (final c in view.challenges) ...<Widget>[
            _ChallengeCard(challenge: c, clicks: view.progress[c.id] ?? 0),
            const SizedBox(height: ZadSpacing.sm),
          ],
      ],
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const new({required this.challenge, required this.clicks});

  final TasbihaChallenge challenge;
  final int clicks;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final target = challenge.targetClicks < 1 ? 1 : challenge.targetClicks;
    final fraction = (clicks / target).clamp(0.0, 1.0);
    final end = challenge.endDate;
    final until = end == null
        ? l.tasOngoing
        : end.substring(0, math.min(10, end.length));
    return ZadWorldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  challenge.title,
                  style: ZadType.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: ZadSpacing.md,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: ZadWorldColors.tasbih.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  challenge.challengeType,
                  style: ZadType.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (challenge.description case final d?) ...<Widget>[
            const SizedBox(height: ZadSpacing.sm),
            Text(
              d,
              style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
            ),
          ],
          const SizedBox(height: ZadSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              color: ZadWorldColors.tasbih,
              backgroundColor: ZadWorldColors.tasbih.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: ZadSpacing.xs),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l.tasbihaProgress(clicks, challenge.targetClicks),
                  style: ZadType.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                until,
                style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
