/// بستان التسبيح on Home, as a world card: the tree drawn for its stage, the
/// real count towards the next stage with «سبحان الله» beside it, and the
/// family challenge ring when one is running. Before the member has a tree
/// there is no count to show, so the card invites the first tasbih instead of
/// printing «0 / 0».
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:zad/core/design/components/zad_pressable.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/tasbiha/application/tasbiha_controller.dart';
import 'package:zad/shared/tasbiha/domain/tasbiha.dart';
import 'package:zad/shared/worlds/art/zad_art.dart';
import 'package:zad/shared/worlds/art/zad_art_kinds.dart';
import 'package:zad/shared/worlds/world_card.dart';
import 'package:zad/shared/worlds/world_row.dart';
import 'package:zad/shared/worlds/zad_world.dart';

// ZadSprings.Celebrate (0.4 / 500) out, ZadSprings.Press (0.55 / 600) back.
const SpringDescription _celebrate = SpringDescription(
  mass: 1,
  stiffness: 500,
  damping: 2 * 0.4 * 22.360679774998,
);
const SpringDescription _press = SpringDescription(
  mass: 1,
  stiffness: 600,
  damping: 2 * 0.55 * 24.494897427832,
);

/// The widget, with Kotlin's `AppearOnEntry` gap below it.
class TasbihaHomeSlot extends ConsumerStatefulWidget {
  /// Creates the slot.
  const new({super.key});

  @override
  ConsumerState<TasbihaHomeSlot> createState() => _TasbihaHomeSlotState();
}

class _TasbihaHomeSlotState extends ConsumerState<TasbihaHomeSlot> {
  @override
  void initState() {
    super.initState();
    // Kotlin's FamilyViewModel reads the tree when home opens.
    unawaited(
      Future<void>.microtask(() {
        if (!mounted) return;
        if (ref.read(tasbihaControllerProvider).myTrees.isEmpty) {
          unawaited(ref.read(tasbihaControllerProvider.notifier).load());
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(tasbihaControllerProvider);
    final challenge = view.challenges.firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: ZadSpacing.lg),
      child: TasbihaHomeWidget(
        tree: view.myTrees.firstOrNull,
        onTasbih: () => ref.read(tasbihaControllerProvider.notifier).tap(),
        onOpen: () => unawaited(ZadScreens.showTasbihaScreen(context)),
        activeChallenge: challenge,
        challengeClicks: challenge == null
            ? 0
            : view.progress[challenge.id] ?? 0,
      ),
    );
  }
}

/// The card.
class TasbihaHomeWidget extends StatefulWidget {
  /// Creates the card.
  const new({
    required this.tree,
    required this.onTasbih,
    required this.onOpen,
    this.activeChallenge,
    this.challengeClicks = 0,
    super.key,
  });

  /// The member's tree, or null before there is one.
  final GardenTree? tree;

  /// «سبحان الله».
  final VoidCallback onTasbih;

  /// Opens the garden.
  final VoidCallback onOpen;

  /// The family challenge, when one is running.
  final TasbihaChallenge? activeChallenge;

  /// The family's clicks on it.
  final int challengeClicks;

  @override
  State<TasbihaHomeWidget> createState() => _TasbihaHomeWidgetState();
}

class _TasbihaHomeWidgetState extends State<TasbihaHomeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tapScale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );
  bool _confetti = false;
  late int _lastLevel = widget.tree?.level ?? 1;

  @override
  void didUpdateWidget(TasbihaHomeWidget old) {
    super.didUpdateWidget(old);
    final level = widget.tree?.level ?? 1;
    if (level > _lastLevel) {
      setState(() => _confetti = true);
      Future<void>.delayed(const Duration(milliseconds: 2200), () {
        if (mounted) setState(() => _confetti = false);
      });
    }
    _lastLevel = level;
  }

  @override
  void dispose() {
    _tapScale.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    unawaited(HapticFeedback.selectionClick());
    widget.onTasbih();
    if (MediaQuery.disableAnimationsOf(context)) return;
    await _tapScale.animateWith(
      SpringSimulation(_celebrate, _tapScale.value, 1.22, 0),
    );
    if (!mounted) return;
    await _tapScale.animateWith(
      SpringSimulation(_press, _tapScale.value, 1, 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tree = widget.tree;
    const world = ZadWorld.tas;

    // The tree grows from a sprout to a tree; no tree yet, the beads.
    final art = tree == null
        ? ZadIconArt.beads
        : tree.level >= 3
        ? ZadIconArt.tree
        : ZadIconArt.sprout;
    final next = tree?.nextLevelAt();
    final mature = tree != null && (next == null || next == 1 << 31);

    final line = tree == null
        ? l10n.tasbihaHomeStart
        : mature
        ? l10n.tasbihaHomeMature(tree.score)
        : '${tree.score} / $next';

    return ZadWorldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Stack(
            alignment: Alignment.center,
            children: <Widget>[
              ZadWorldRow(
                leading: ZadWorldTile(
                  color: world.color,
                  child: ScaleTransition(
                    scale: _tapScale,
                    child: ZadArt.icon(art, size: 28),
                  ),
                ),
                title: l10n.tasbihaGarden,
                subtitle: line,
                stateColor: world.color,
                progress: tree?.progressToNext(),
                onTap: widget.onOpen,
                trailing: tree == null ? null : _TasbihButton(onPressed: _tap),
              ),
              if (_confetti)
                IgnorePointer(
                  child: Lottie.asset(
                    'assets/lottie/lottie_confetti_burst.json',
                    width: 140,
                    height: 140,
                    repeat: false,
                  ),
                ),
            ],
          ),
          if (widget.activeChallenge case final c?) ...<Widget>[
            const SizedBox(height: ZadSpacing.md),
            _ChallengeRow(challenge: c, clicks: widget.challengeClicks),
          ],
        ],
      ),
    );
  }
}

/// «سبحان الله»: the dhikr itself, so it stays Arabic in every locale.
class _TasbihButton extends StatelessWidget {
  const new({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ZadPressable(
    scale: 0.96,
    onPressed: onPressed,
    child: Container(
      constraints: const BoxConstraints(minHeight: 44),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ZadRadii.chip),
        color: ZadWorld.tas.color,
      ),
      child: Text(
        'سبحان الله', // l10n: data
        style: ZadType.labelLarge.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

/// The family challenge: a real progress ring, hidden when none runs — no
/// fake empty state.
class _ChallengeRow extends StatelessWidget {
  const new({required this.challenge, required this.clicks});

  final TasbihaChallenge challenge;
  final int clicks;

  @override
  Widget build(BuildContext context) {
    final target = challenge.targetClicks < 1 ? 1 : challenge.targetClicks;
    final progress = (clicks / target).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZadSpacing.md,
        vertical: ZadSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: ZadWorld.tas.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ZadRadii.chip),
      ),
      child: Row(
        children: <Widget>[
          SizedBox.square(
            dimension: 40,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                SizedBox.square(
                  dimension: 40,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 4,
                    color: ZadWorld.tas.color,
                    backgroundColor: ZadWorld.tas.color.withValues(alpha: 0.15),
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: ZadType.labelSmall.copyWith(
                    color: ZadWorld.tas.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: ZadSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  challenge.title,
                  maxLines: 1,
                  style: ZadType.titleSmall.copyWith(
                    color: ZadColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  context.l10n.tasbihaProgress(clicks, challenge.targetClicks),
                  style: ZadType.labelMedium.copyWith(
                    color: ZadColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
