/// ONE identity for every page of the app (owner, 15/11).
///
/// `ZadWorldScaffold` is the only place that decides a world's header layout,
/// the eyebrow / title / state-line type, the card style (`ZadWorldCard`),
/// spacing, the back button, the «متصلة بـ» strip, the backdrop and how the
/// companion stands in the scene. A world may vary ONLY: its [ZadWorld]
/// (colour), its scene painter, the companion's pose and position
/// ([ZadWorldZado]), and its body slivers. There are deliberately no
/// parameters for fonts, paddings or header layout — if a page needs one,
/// change it here, for all pages. The backdrop rule (a tenth of the world
/// colour over white, down to the canvas) lives in `ZadWorldColors.tint`.
///
/// The companion is the customer's own (`companionLookProvider`: persona,
/// stage, outfit); Zado's default look only when none is saved yet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/design/tokens/zad_world_colors.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/companion/application/companion_controller.dart';
import 'package:zad/shared/companion/domain/companion_catalog.dart';
import 'package:zad/shared/orb/domain/companion_state.dart';
import 'package:zad/shared/orb/domain/orb_occasion.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';
import 'package:zad/shared/worlds/world_links.dart';
import 'package:zad/shared/worlds/world_scene.dart';
import 'package:zad/shared/worlds/zad_world.dart';

/// Paints a scene in the 430×230 design space; repaints from [loop].
typedef ZadSceneBuilder = CustomPainter Function(Animation<double> loop);

/// Where the companion stands in the scene, in design-space units, and how
/// it feels.
@immutable
class ZadWorldZado {
  /// Creates a placement.
  const new({
    this.left = 40,
    this.top = 40,
    this.size = 150,
    this.state = CompanionState.happy,
  });

  /// Distance from the scene's left edge.
  final double left;

  /// Distance from the scene's top.
  final double top;

  /// The box it is drawn in.
  final double size;

  /// Its mood — the pose.
  final CompanionState state;
}

/// One world's page.
class ZadWorldScaffold extends ConsumerStatefulWidget {
  /// Creates a world page. [slivers] are the body, under the scene; the
  /// links strip follows them. [showBack] defaults to "this route can pop".
  /// [overlay] floats above the scroll (a button), [onRefresh] adds
  /// pull-to-refresh, [bottomInset] keeps the last card clear of a floating
  /// button.
  const new({
    required this.world,
    required this.title,
    required this.scene,
    required this.slivers,
    this.eyebrow,
    this.stateLine,
    this.zado = const ZadWorldZado(),
    this.showBack,
    this.overlay,
    this.onRefresh,
    this.bottomInset = ZadSpacing.xl,
    super.key,
  });

  /// Which world — its colour and its links.
  final ZadWorld world;

  /// The heavy title.
  final String title;

  /// Small line above the title, in the world colour.
  final String? eyebrow;

  /// The one state line under the title, in the world colour.
  final String? stateLine;

  /// The scene.
  final ZadSceneBuilder scene;

  /// The companion's pose and position.
  final ZadWorldZado zado;

  /// The body.
  final List<Widget> slivers;

  /// Show the back button; null shows it when the route can pop.
  final bool? showBack;

  /// Floats over the scroll.
  final Widget? overlay;

  /// Pull-to-refresh.
  final Future<void> Function()? onRefresh;

  /// Space after the links strip.
  final double bottomInset;

  @override
  ConsumerState<ZadWorldScaffold> createState() => _ZadWorldScaffoldState();
}

class _ZadWorldScaffoldState extends ConsumerState<ZadWorldScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6400),
  );

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
    final w = widget.world;
    final back = widget.showBack ?? (ModalRoute.of(context)?.canPop ?? false);
    final look = ref.watch(companionLookProvider) ?? const CompanionLook();
    Widget scroll = CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(child: _header(context, back, look)),
        ...widget.slivers,
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            ZadSpacing.gutter,
            ZadSpacing.lg,
            ZadSpacing.gutter,
            widget.bottomInset,
          ),
          sliver: SliverToBoxAdapter(child: ZadWorldLinks(world: w)),
        ),
      ],
    );
    if (widget.onRefresh != null) {
      scroll = RefreshIndicator(onRefresh: widget.onRefresh!, child: scroll);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[ZadWorldColors.tint(w.color), ZadColors.canvasMid],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: scroll),
          ?widget.overlay,
        ],
      ),
    );
  }

  Widget _header(BuildContext context, bool back, CompanionLook look) {
    final l = context.l10n;
    final w = widget.world;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ZadSpacing.gutter,
            ZadSpacing.md,
            ZadSpacing.gutter,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (back)
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: l.worldBack,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: ZadColors.ink,
                  ),
                ),
              if (widget.eyebrow != null)
                Text(
                  widget.eyebrow!,
                  style: ZadType.labelMedium.copyWith(
                    color: w.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              Text(
                widget.title,
                style: ZadType.worldTitle.copyWith(color: ZadColors.ink),
              ),
              if (widget.stateLine != null) ...<Widget>[
                const SizedBox(height: ZadSpacing.xs),
                Text(
                  widget.stateLine!,
                  style: ZadType.titleMedium.copyWith(
                    color: w.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: ZadSpacing.sm),
        _scene(look),
      ],
    );
  }

  Widget _scene(CompanionLook look) {
    final z = widget.zado;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return LayoutBuilder(
      builder: (context, c) {
        final s = c.maxWidth / kWorldSceneSize.width;
        return Directionality(
          textDirection: TextDirection.ltr,
          child: ExcludeSemantics(
            child: SizedBox(
              width: c.maxWidth,
              height: kWorldSceneSize.height * s,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: ScaledScene(widget.scene(_loop), s),
                      ),
                    ),
                  ),
                  Positioned(
                    left: z.left * s,
                    top: z.top * s,
                    child: CompanionOrb(
                      look: look,
                      occasion: OrbOccasion.none,
                      state: z.state,
                      size: z.size * s,
                      animated: !still,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
