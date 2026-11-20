/// بستاني: the dhikr chips, the tree's state card and the member's trees.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/components/zad_empty_state.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/tasbiha/domain/tasbiha.dart';
import 'package:zad/shared/worlds/art/art.dart';
import 'package:zad/shared/worlds/world_card.dart';

/// A flower for every 33 counts.
int flowersOf(int score) => score ~/ 33;

/// The stage's name, in the customer's language.
String tasbihaStageName(ZadL10n l, int level) => switch (level) {
  >= 5 => l.tasStage5,
  4 => l.tasStage4,
  3 => l.tasStage3,
  2 => l.tasStage2,
  _ => l.tasStage1,
};

/// The dhikr chips: a tap renames the counting tree to that dhikr.
class TasbihaDhikrChips extends StatelessWidget {
  /// Creates the row.
  const new({required this.current, required this.onPick, super.key});

  /// The tree's present dhikr.
  final String? current;

  /// A chip was tapped.
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: kQuickDhikrs.length,
      separatorBuilder: (_, _) => const SizedBox(width: ZadSpacing.sm),
      itemBuilder: (context, i) {
        final dhikr = kQuickDhikrs[i];
        final on = current == dhikr;
        return FilterChip(
          selected: on,
          showCheckmark: false,
          onSelected: (_) => onPick(dhikr),
          selectedColor: ZadWorldColors.tasbih,
          backgroundColor: ZadColors.surface,
          side: BorderSide(
            color: on
                ? ZadWorldColors.tasbih
                : ZadColors.outline.withValues(alpha: 0.3),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZadRadii.chip + 8),
          ),
          label: Text(
            dhikr,
            style: ZadType.bodySmall.copyWith(
              color: on ? Colors.white : ZadColors.ink,
              fontWeight: on ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        );
      },
    ),
  );
}

/// The selected tree: its name (a tap renames it), stage, progress to the
/// next stage and the four numbers.
class TasbihaTreeCard extends StatelessWidget {
  /// Creates the card.
  const new({
    required this.tree,
    required this.sessionTaps,
    required this.onRename,
    super.key,
  });

  /// The counting tree.
  final GardenTree tree;

  /// Counts made since this screen opened.
  final int sessionTaps;

  /// Rename was asked for.
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ZadWorldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  tree.treeName,
                  style: ZadType.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: l.tasRenameTitle,
                onPressed: onRename,
                style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                icon: const Icon(ZadIcons.edit, size: 20),
              ),
            ],
          ),
          Text(
            tasbihaStageName(l, tree.level),
            style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
          ),
          const SizedBox(height: ZadSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: tree.progressToNext(),
              minHeight: 8,
              stopIndicatorRadius: 0,
              trackGap: 0,
              color: ZadWorldColors.tasbih,
              backgroundColor: ZadWorldColors.tasbih.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: ZadSpacing.xs),
          Text(
            tree.level < 5
                ? l.tasNext(tree.score, tree.nextLevelAt())
                : l.tasComplete,
            style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
          ),
          const SizedBox(height: ZadSpacing.lg),
          Row(
            children: <Widget>[
              _Stat(
                label: l.tasStatLevel,
                value: l.tasStatLevelValue(tree.level),
                art: ZadIconArt.tree,
              ),
              _Stat(
                label: l.tasStatFlowers,
                value: '${flowersOf(tree.score)}',
                art: ZadIconArt.star,
              ),
              _Stat(
                label: l.tasStatTotal,
                value: '${tree.totalClicks}',
                art: ZadIconArt.beads,
              ),
              _Stat(
                label: l.tasStatStreak,
                value: '${tree.streakDays}',
                art: ZadIconArt.flame,
              ),
            ],
          ),
          if (sessionTaps > 0) ...<Widget>[
            const SizedBox(height: ZadSpacing.md),
            Text(
              '${l.tasStatSession}: $sessionTaps',
              style: ZadType.labelMedium.copyWith(
                color: ZadWorldColors.tasbih,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const new({required this.label, required this.value, required this.art});

  final String label;
  final String value;
  final ZadIconArt art;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: <Widget>[
        ZadArt.icon(art, size: 28),
        const SizedBox(height: ZadSpacing.xs),
        Text(
          value,
          style: ZadType.bodyLarge.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
        ),
      ],
    ),
  );
}

/// «أشجاري»: the member's trees, a tap picks the one being counted.
class TasbihaMyTrees extends StatelessWidget {
  /// Creates the card.
  const new({
    required this.trees,
    required this.selectedId,
    required this.onSelect,
    required this.onNew,
    super.key,
  });

  /// The member's trees.
  final List<GardenTree> trees;

  /// The one being counted.
  final String? selectedId;

  /// A tree was picked.
  final ValueChanged<GardenTree> onSelect;

  /// «شجرة جديدة».
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ZadWorldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l.tasMyTrees(trees.length),
                  style: ZadType.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: onNew,
                icon: const Icon(ZadIcons.add, size: 18),
                label: Text(l.tasNewTree),
              ),
            ],
          ),
          const SizedBox(height: ZadSpacing.sm),
          if (trees.isEmpty)
            ZadEmptyState(
              icon: ZadIcons.tree,
              title: l.tasNoTreeTitle,
              message: l.tasNoTreeMsg,
            )
          else
            Wrap(
              spacing: ZadSpacing.sm,
              runSpacing: ZadSpacing.sm,
              children: <Widget>[
                for (final t in trees)
                  _TreeChip(
                    tree: t,
                    selected: t.id == selectedId,
                    onTap: () => onSelect(t),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TreeChip extends StatelessWidget {
  const new({required this.tree, required this.selected, required this.onTap});

  final GardenTree tree;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? ZadWorldColors.tasbih.withValues(alpha: 0.14)
        : ZadColors.surfaceLow,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ZadRadii.card),
      side: BorderSide(
        color: selected ? ZadWorldColors.tasbih : Colors.transparent,
        width: 2,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 88, minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.all(ZadSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ZadArt.icon(ZadIconArt.tree, size: 24),
              const SizedBox(height: ZadSpacing.xs),
              Text(
                tree.treeName.length > 10
                    ? tree.treeName.substring(0, 10)
                    : tree.treeName,
                maxLines: 1,
                style: ZadType.labelSmall,
              ),
              Text(
                '${tree.score}',
                style: ZadType.labelSmall.copyWith(
                  color: ZadWorldColors.tasbih,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
