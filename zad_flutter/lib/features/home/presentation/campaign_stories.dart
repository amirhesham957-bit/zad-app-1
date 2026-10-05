/// «حكايات زاد»: the occasion's story as a circle at the top of home, like
/// a stories strip. Tapped, its slides play full screen — one line each, a
/// bar per slide, a tap on either side to move — and swiping up (or the
/// button) asks زاد to do the occasion's job, as the banner does. Nothing is
/// sent on open. A seen story's ring fades until the next occasion.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/home/application/home_campaign.dart';
import 'package:zad/features/home/presentation/campaign_banner.dart';
import 'package:zad/shared/campaigns/domain/campaign.dart';
import 'package:zad/shared/chat/application/chat_controller.dart';
import 'package:zad/shared/navigation/shell_navigation.dart';

const String _seenKey = 'story_seen';

/// The strip, or nothing.
class CampaignStoriesStrip extends ConsumerStatefulWidget {
  /// Creates the strip.
  const new({super.key});

  @override
  ConsumerState<CampaignStoriesStrip> createState() => _StripState();
}

class _StripState extends ConsumerState<CampaignStoriesStrip> {
  late String? _seen = ref.read(localStoreProvider).device.get(_seenKey);

  void _open(ActiveCampaign active) {
    setState(() => _seen = active.key);
    unawaited(ref.read(localStoreProvider).device.put(_seenKey, active.key));
    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: ZadDuration.enter,
        pageBuilder: (_, _, _) =>
            CampaignStoryViewer(active: active, onAsk: () => _ask(active)),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  void _ask(ActiveCampaign active) {
    unawaited(
      ref.read(chatControllerProvider.notifier).send(active.campaign.ctaPrompt),
    );
    ref.read(shellNavigationProvider.notifier).open(ShellTab.chat);
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(homeCampaignProvider);
    if (active == null || active.campaign.slides.isEmpty) {
      return const SizedBox.shrink();
    }
    final c = active.campaign;
    final seen = _seen == active.key;
    final gradient = campaignGradient(active);
    return Padding(
      padding: const EdgeInsets.only(bottom: ZadSpacing.md),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(
          button: true,
          label: 'حكايات زاد: ${c.eventName ?? c.title}',
          child: InkWell(
            onTap: () => _open(active),
            customBorder: const CircleBorder(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // An unseen story is ringed in the occasion's colours.
                    gradient: seen ? null : (gradient ?? ZadColors.wallet),
                    color: seen ? ZadColors.outline : null,
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ZadColors.surface,
                      border: Border.all(color: ZadColors.surface, width: 2),
                    ),
                    child: Text(
                      c.badge.isEmpty ? '✨' : c.badge,
                      style: ZadType.headlineMedium.copyWith(height: 1),
                    ),
                  ),
                ),
                const SizedBox(height: ZadSpacing.xs),
                ExcludeSemantics(
                  child: Text(
                    c.eventName ?? 'حكايات زاد',
                    style: ZadType.labelSmall.copyWith(
                      color: seen ? ZadColors.inkMuted : ZadColors.ink,
                      fontWeight: seen ? FontWeight.w400 : FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The slides, full screen. Closes and calls [onAsk] when the customer asks
/// زاد.
class CampaignStoryViewer extends StatefulWidget {
  /// Creates the viewer.
  const new({required this.active, required this.onAsk, super.key});

  /// Whose story.
  final ActiveCampaign active;

  /// The swipe up or the button.
  final VoidCallback onAsk;

  @override
  State<CampaignStoryViewer> createState() => _ViewerState();
}

class _ViewerState extends State<CampaignStoryViewer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: ZadDuration.storySlide,
  )..addStatusListener(_onTick);
  int _index = 0;
  bool _still = false;

  List<StorySlide> get _slides => widget.active.campaign.slides;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: no clock — the customer moves the slides by tapping.
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.forward(from: 0);
    }
  }

  void _onTick(AnimationStatus status) {
    if (status == AnimationStatus.completed) _go(1);
  }

  void _go(int step) {
    final next = _index + step;
    if (next < 0) {
      if (!_still) _clock.forward(from: 0);
      return;
    }
    if (next >= _slides.length) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _index = next);
    if (!_still) _clock.forward(from: 0);
  }

  void _ask() {
    _clock.stop();
    Navigator.of(context).pop();
    widget.onAsk();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.active.campaign;
    final slide = _slides[_index];
    const white = Colors.white;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // The start third goes back; anywhere else goes on.
        onTapUp: (d) {
          final width = MediaQuery.sizeOf(context).width;
          final x = rtl ? width - d.globalPosition.dx : d.globalPosition.dx;
          _go(x < width / 3 ? -1 : 1);
        },
        onVerticalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -300) _ask();
          if (v > 300) Navigator.of(context).pop();
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: campaignGradient(widget.active) ?? ZadColors.wallet,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(ZadSpacing.lg),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      for (var i = 0; i < _slides.length; i++) ...<Widget>[
                        if (i > 0) const SizedBox(width: ZadSpacing.xs),
                        Expanded(
                          child: _Bar(
                            clock: _clock,
                            state: i < _index
                                ? 1
                                : i > _index
                                ? 0
                                : null,
                            still: _still,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: ZadSpacing.md),
                  Row(
                    children: <Widget>[
                      Text(c.badge, style: ZadType.titleLarge),
                      const SizedBox(width: ZadSpacing.sm),
                      Expanded(
                        child: Text(
                          c.eventName ?? 'حكايات زاد',
                          style: ZadType.titleMedium.copyWith(
                            color: white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'إغلاق',
                        onPressed: () => Navigator.of(context).pop(),
                        constraints: const BoxConstraints.tightFor(
                          width: kZadMinTapTarget,
                          height: kZadMinTapTarget,
                        ),
                        icon: const Icon(ZadIcons.dismiss, color: white),
                      ),
                    ],
                  ),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: ZadDuration.enter,
                    switchInCurve: ZadCurves.standard,
                    child: Column(
                      key: ValueKey<int>(_index),
                      children: <Widget>[
                        Text(slide.emoji, style: ZadType.displayLarge),
                        const SizedBox(height: ZadSpacing.lg),
                        Text(
                          slide.text,
                          textAlign: TextAlign.center,
                          style: ZadType.headlineMedium.copyWith(
                            color: white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // The thumb zone: the one thing this story asks.
                  const Icon(Icons.keyboard_arrow_up, color: white),
                  FilledButton(
                    onPressed: _ask,
                    style: FilledButton.styleFrom(
                      backgroundColor: white,
                      foregroundColor: campaignGradient(widget.active) != null
                          ? Color(c.primary)
                          : ZadColors.emeraldDeep,
                      minimumSize: const Size.fromHeight(kZadMinTapTarget + 4),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      c.ctaText,
                      style: ZadType.labelLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One slide's bar: full when seen, empty when ahead, filling while shown.
class _Bar extends StatelessWidget {
  const new({required this.clock, required this.state, required this.still});

  final Animation<double> clock;

  /// 1 seen, 0 ahead, null the current one.
  final double? state;

  final bool still;

  @override
  Widget build(BuildContext context) {
    Widget bar(double v) => ClipRRect(
      borderRadius: BorderRadius.circular(ZadRadii.pill),
      child: LinearProgressIndicator(
        value: v,
        minHeight: 3,
        color: Colors.white,
        backgroundColor: Colors.white.withValues(alpha: 0.3),
      ),
    );
    final s = state;
    if (s != null) return bar(s);
    if (still) return bar(1);
    return AnimatedBuilder(
      animation: clock,
      builder: (_, _) => bar(clock.value),
    );
  }
}
