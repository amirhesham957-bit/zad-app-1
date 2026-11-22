/// The chat world's compact header: the title and one state line from what
/// the conversation is doing, the customer's own companion posed to match,
/// and the controls that used to live in the app bar (back, attempts, the
/// brain hub, a new conversation). The scene folds away when `collapsed`, so
/// the header never eats the conversation.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/companion/application/companion_controller.dart';
import 'package:zad/shared/companion/domain/companion_catalog.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/orb/domain/orb_occasion.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';
import 'package:zad/shared/quota/presentation/attempts_chip.dart';

/// The header.
class ChatWorldHeader extends ConsumerStatefulWidget {
  /// Creates the header.
  const new({
    required this.title,
    required this.eyebrow,
    required this.stateLine,
    required this.pose,
    required this.collapsed,
    required this.showClear,
    required this.onClear,
    super.key,
  });

  /// The world's label.
  final String title;

  /// The small line above the title.
  final String eyebrow;

  /// What the conversation is doing, from real state.
  final String stateLine;

  /// The companion's pose.
  final CompanionState pose;

  /// Whether the scene is folded away.
  final bool collapsed;

  /// Whether there is a conversation to clear.
  final bool showClear;

  /// Asks to start a new conversation.
  final VoidCallback onClear;

  @override
  ConsumerState<ChatWorldHeader> createState() => _HeaderState();
}

class _HeaderState extends ConsumerState<ChatWorldHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  static const double _sceneHeight = 96;

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
    final look = ref.watch(companionLookProvider) ?? const CompanionLook();
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final thinking = widget.pose == CompanionState.focused;
    const world = ZadWorldColors.chat;

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
                      if (!widget.collapsed)
                        Text(
                          widget.eyebrow,
                          style: ZadType.labelMedium.copyWith(
                            color: world,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      Text(
                        widget.title,
                        style: widget.collapsed
                            ? ZadType.titleLarge.copyWith(
                                color: ZadColors.ink,
                                fontWeight: FontWeight.w900,
                              )
                            : ZadType.worldTitle.copyWith(color: ZadColors.ink),
                      ),
                      Text(
                        widget.stateLine,
                        style: ZadType.titleMedium.copyWith(
                          color: world,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const AttemptsChip(),
              IconButton(
                onPressed: () => ZadScreens.showBrainHub(context),
                icon: const Icon(ZadIcons.brain),
                tooltip: l.drawerBrain,
                style: IconButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  foregroundColor: world,
                ),
              ),
              if (widget.showClear)
                IconButton(
                  onPressed: widget.onClear,
                  icon: const Icon(ZadIcons.dismiss),
                  tooltip: l.chatNewTooltip,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: ZadColors.inkMuted,
                  ),
                ),
            ],
          ),
          AnimatedSize(
            duration: still ? Duration.zero : ZadDuration.enter,
            curve: ZadCurves.standard,
            alignment: Alignment.topCenter,
            child: widget.collapsed
                ? const SizedBox(width: double.infinity)
                : SizedBox(
                    height: _sceneHeight,
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: ExcludeSemantics(
                        child: Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  painter: ChatWorldScene(
                                    _loop,
                                    thinking: thinking,
                                  ),
                                ),
                              ),
                            ),
                            CompanionOrb(
                              look: look,
                              occasion: OrbOccasion.none,
                              state: widget.pose,
                              size: 84,
                              animated: !still,
                            ),
                          ],
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

/// The ground under the companion, soft rings spreading from it (faster and
/// stronger while a reply is coming), and three dots that hop while it
/// thinks.
class ChatWorldScene extends CustomPainter {
  /// Creates the painter.
  new(this.loop, {required this.thinking}) : super(repaint: loop);

  /// The header's loop.
  final Animation<double> loop;

  /// Whether a reply is being written.
  final bool thinking;

  @override
  void paint(Canvas canvas, Size size) {
    const world = ZadWorldColors.chat;
    final c = Offset(size.width / 2, size.height / 2);
    final t = loop.value;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx, size.height - 8),
        width: math.min(size.width, 320),
        height: 16,
      ),
      Paint()..color = world.withValues(alpha: 0.14),
    );
    for (var i = 0; i < 2; i++) {
      final p = (t * (thinking ? 2 : 1) + i / 2) % 1;
      canvas.drawCircle(
        c,
        46 + 34 * p,
        Paint()
          ..color = world.withValues(alpha: (thinking ? 0.28 : 0.12) * (1 - p))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
    if (thinking) {
      for (var i = 0; i < 3; i++) {
        final hop = math.max(0, math.sin((t * 2 - i * 0.12) * 2 * math.pi));
        canvas.drawCircle(
          Offset(c.dx + 62 + i * 14, c.dy - 30 - 6 * hop),
          4,
          Paint()..color = world.withValues(alpha: 0.7),
        );
      }
    }
  }

  @override
  bool shouldRepaint(ChatWorldScene old) => old.thinking != thinking;
}
