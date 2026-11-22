/// The family chat's compact header: the world's title and one state line,
/// the customer's companion beside the little house, and the SOS that must
/// stay one tap away in the chat. The scene folds away while the keyboard is
/// open, so the header never eats the conversation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/family/presentation/family_scene.dart';
import 'package:zad/shared/companion/application/companion_controller.dart';
import 'package:zad/shared/companion/domain/companion_catalog.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/orb/domain/orb_occasion.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';
import 'package:zad/shared/worlds/world_scene.dart';

/// The header.
class FamilyChatHeader extends ConsumerStatefulWidget {
  /// Creates the header.
  const new({
    required this.title,
    required this.stateLine,
    required this.members,
    required this.pose,
    required this.onSos,
    super.key,
  });

  /// The family's name.
  final String title;

  /// One line from real state.
  final String stateLine;

  /// How many people are in the family.
  final int members;

  /// The companion's pose.
  final CompanionState pose;

  /// Sends the emergency call (after its confirmation).
  final VoidCallback onSos;

  @override
  ConsumerState<FamilyChatHeader> createState() => _State();
}

class _State extends ConsumerState<FamilyChatHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6400),
  );

  static const double _scale = 0.4;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _loop
        ..stop()
        ..value = 0.25;
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;
    final look = ref.watch(companionLookProvider) ?? const CompanionLook();
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    const world = ZadWorldColors.family;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZadSpacing.sm,
        ZadSpacing.xs,
        ZadSpacing.sm,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (canPop)
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: l.worldBack,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: ZadColors.ink,
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZadSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l.worldLabelFamily,
                        style: ZadType.labelMedium.copyWith(
                          color: world,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ZadType.titleLarge.copyWith(
                          color: ZadColors.ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        widget.stateLine,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ZadType.labelLarge.copyWith(
                          color: world,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: l.familyActionSos,
                onPressed: widget.onSos,
                icon: const Icon(ZadIcons.sos),
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: Colors.white,
                  backgroundColor: ZadColors.terracottaRust,
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: still ? Duration.zero : ZadDuration.enter,
            curve: ZadCurves.standard,
            alignment: Alignment.topCenter,
            child: typing
                ? const SizedBox(width: double.infinity)
                : SizedBox(
                    height: kWorldSceneSize.height * _scale,
                    child: Center(
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: ExcludeSemantics(
                          child: SizedBox(
                            width: kWorldSceneSize.width * _scale,
                            height: kWorldSceneSize.height * _scale,
                            child: Stack(
                              children: <Widget>[
                                Positioned.fill(
                                  child: RepaintBoundary(
                                    child: CustomPaint(
                                      painter: ScaledScene(
                                        FamilyWorldScene(
                                          _loop,
                                          members: widget.members,
                                        ),
                                        _scale,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 30 * _scale,
                                  top: 52 * _scale,
                                  child: CompanionOrb(
                                    look: look,
                                    occasion: OrbOccasion.none,
                                    state: widget.pose,
                                    size: 140 * _scale,
                                    animated: !still,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
