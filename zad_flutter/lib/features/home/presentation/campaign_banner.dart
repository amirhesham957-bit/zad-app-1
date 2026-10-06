/// The seasonal banner (`app_campaigns`): the occasion's colours, its badge,
/// a quiet snow or confetti behind the text, and one button that asks زاد to
/// do the occasion's job — a chat message, sent on the tap and never on open.
/// Dismissed, it stays hidden until the occasion comes round again.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/features/home/application/home_campaign.dart';
import 'package:zad/features/home/presentation/occasion_card.dart';
import 'package:zad/shared/campaigns/domain/campaign.dart';
import 'package:zad/shared/chat/application/chat_controller.dart';
import 'package:zad/shared/navigation/shell_navigation.dart';

const String _dismissedKey = 'dismissed_campaign';

/// The campaign's gradient, or null when its colours would not keep white
/// text readable (then زاد's own colours are used).
LinearGradient? campaignGradient(ActiveCampaign? active) {
  final c = active?.campaign;
  if (c == null || !c.readableOnWhite) return null;
  return LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: <Color>[Color(c.primary), Color(c.secondary)],
  );
}

/// The banner, or nothing.
class CampaignBannerSlot extends ConsumerStatefulWidget {
  /// Creates the slot.
  const new({super.key});

  @override
  ConsumerState<CampaignBannerSlot> createState() => _CampaignBannerSlotState();
}

class _CampaignBannerSlotState extends ConsumerState<CampaignBannerSlot> {
  late String? _dismissed = ref
      .read(localStoreProvider)
      .device
      .get(_dismissedKey);

  void _dismiss(ActiveCampaign active) {
    setState(() => _dismissed = active.key);
    unawaited(
      ref.read(localStoreProvider).device.put(_dismissedKey, active.key),
    );
  }

  void _ask(Campaign campaign) {
    unawaited(
      ref.read(chatControllerProvider.notifier).send(campaign.ctaPrompt),
    );
    ref.read(shellNavigationProvider.notifier).open(ShellTab.chat);
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(homeCampaignProvider);
    if (active == null || active.key == _dismissed) {
      return const SizedBox.shrink();
    }
    // On an occasion's day the occasion card has the home to itself, all
    // day, put away or not: two cards offering the same thing is clutter
    // (owner, 2026-10-05). The rim, the badge and the colours stay.
    if (ref.watch(occasionTodayProvider) != null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: ZadSpacing.lg),
      child: CampaignBanner(
        active: active,
        onAsk: () => _ask(active.campaign),
        onDismiss: () => _dismiss(active),
      ),
    );
  }
}

/// The card itself.
class CampaignBanner extends StatelessWidget {
  /// Creates the card.
  const new({
    required this.active,
    required this.onAsk,
    required this.onDismiss,
    super.key,
  });

  /// What it shows.
  final ActiveCampaign active;

  /// The button.
  final VoidCallback onAsk;

  /// The close mark.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = active.campaign;
    final gradient = campaignGradient(active);
    final still = MediaQuery.disableAnimationsOf(context);
    const white = Colors.white;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ZadRadii.cardLarge),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient ?? ZadColors.wallet),
        child: Stack(
          children: <Widget>[
            if (c.particles != CampaignParticles.none)
              Positioned.fill(
                child: IgnorePointer(
                  child: CampaignParticlesLayer(
                    kind: c.particles,
                    tint: Color(c.primary),
                    intensity: active.intensity,
                    still: still,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                ZadSpacing.lg,
                ZadSpacing.lg,
                ZadSpacing.xs,
                ZadSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (c.badge.isNotEmpty ||
                          c.lottieUrl != null) ...<Widget>[
                        CampaignBadge(campaign: c, size: 48, still: still),
                        const SizedBox(width: ZadSpacing.md),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              c.title,
                              style: ZadType.titleMedium.copyWith(
                                fontWeight: FontWeight.w800,
                                color: white,
                              ),
                            ),
                            const SizedBox(height: ZadSpacing.xs),
                            Text(
                              c.body,
                              style: ZadType.bodyMedium.copyWith(
                                color: white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'إخفاء',
                        onPressed: onDismiss,
                        constraints: const BoxConstraints.tightFor(
                          width: kZadMinTapTarget,
                          height: kZadMinTapTarget,
                        ),
                        icon: Icon(
                          ZadIcons.dismiss,
                          size: 20,
                          color: white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ZadSpacing.md),
                  FilledButton(
                    onPressed: onAsk,
                    style: FilledButton.styleFrom(
                      backgroundColor: white,
                      // The campaign's colour on white reads as well as white
                      // on it; a colour that fails gets زاد's deep green.
                      foregroundColor: gradient != null
                          ? Color(c.primary)
                          : ZadColors.emeraldDeep,
                      minimumSize: const Size(0, kZadMinTapTarget),
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
          ],
        ),
      ),
    );
  }
}

/// The occasion's badge: its Lottie when one is set and loads, else its
/// emoji, bobbing gently unless the phone asks for reduced motion.
class CampaignBadge extends StatefulWidget {
  /// Creates the badge.
  const new({
    required this.campaign,
    required this.size,
    this.still = false,
    super.key,
  });

  /// Whose badge.
  final Campaign campaign;

  /// Its diameter.
  final double size;

  /// No motion.
  final bool still;

  @override
  State<CampaignBadge> createState() => _CampaignBadgeState();
}

class _CampaignBadgeState extends State<CampaignBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: ZadDuration.shimmer,
  );

  @override
  void initState() {
    super.initState();
    if (!widget.still) _bob.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(CampaignBadge old) {
    super.didUpdateWidget(old);
    if (widget.still == old.still) return;
    if (widget.still) {
      _bob.stop();
    } else {
      _bob.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.campaign;
    final emoji = Text(
      c.badge,
      style: ZadType.headlineMedium.copyWith(height: 1),
      textAlign: TextAlign.center,
    );
    final url = c.lottieUrl;
    final face = url == null
        ? emoji
        : Lottie.network(
            url,
            width: widget.size,
            height: widget.size,
            animate: !widget.still,
            errorBuilder: (_, _, _) => emoji,
          );
    return AnimatedBuilder(
      animation: _bob,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -3 * ZadCurves.standard.transform(_bob.value)),
        child: child,
      ),
      child: Container(
        width: widget.size,
        height: widget.size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.16),
        ),
        child: face,
      ),
    );
  }
}

/// Snow, confetti or sparkles drawn behind the banner's text, as many as the
/// day's intensity (`kParticleCounts`) on one repaint boundary; frozen in
/// place under reduced motion.
class CampaignParticlesLayer extends StatefulWidget {
  /// Creates the layer.
  const new({
    required this.kind,
    required this.tint,
    this.intensity = CampaignIntensity.medium,
    this.still = false,
    super.key,
  });

  /// Which effect.
  final CampaignParticles kind;

  /// The campaign's colour, lightened for confetti.
  final Color tint;

  /// How many: a quiet season day, the days around the peak, the peak.
  final CampaignIntensity intensity;

  /// No motion.
  final bool still;

  @override
  State<CampaignParticlesLayer> createState() => _CampaignParticlesLayerState();
}

class _CampaignParticlesLayerState extends State<CampaignParticlesLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: ZadDuration.ambient,
  );

  @override
  void initState() {
    super.initState();
    if (!widget.still) _loop.repeat();
  }

  @override
  void didUpdateWidget(CampaignParticlesLayer old) {
    super.didUpdateWidget(old);
    if (widget.still == old.still) return;
    if (widget.still) {
      _loop.stop();
    } else {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _ParticlesPainter(
        widget.kind,
        widget.tint,
        kParticleCounts[widget.intensity]!,
        _loop,
      ),
    ),
  );
}

typedef _Seed = ({double x, double y, double size, double phase});

/// Particles per intensity — the medium count is the eighteen the banner
/// always had.
const Map<CampaignIntensity, int> kParticleCounts = <CampaignIntensity, int>{
  CampaignIntensity.low: 8,
  CampaignIntensity.medium: 18,
  CampaignIntensity.peak: 30,
};

final List<_Seed> _seeds = List<_Seed>.generate(30, (i) {
  final r = math.Random(i * 7919 + 13);
  return (
    x: r.nextDouble(),
    y: r.nextDouble(),
    size: r.nextDouble(),
    phase: r.nextDouble(),
  );
}, growable: false);

class _ParticlesPainter extends CustomPainter {
  new(this.kind, this.tint, this.count, this.progress)
    : super(repaint: progress);

  final CampaignParticles kind;
  final Color tint;
  final int count;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    final paint = Paint();
    const tau = 2 * math.pi;
    final confetti = <Color>[
      Colors.white,
      Color.lerp(tint, Colors.white, 0.55)!,
      Color.lerp(tint, Colors.white, 0.8)!,
    ];
    for (var i = 0; i < count; i++) {
      final s = _seeds[i];
      switch (kind) {
        case CampaignParticles.snow:
          final y = (s.y + t * (0.6 + 0.4 * s.size)) % 1;
          final x = s.x + 0.02 * math.sin(tau * (2 * t + s.phase));
          paint.color = Colors.white.withValues(alpha: 0.5);
          canvas.drawCircle(
            Offset(x * size.width, y * size.height),
            1.2 + 1.8 * s.size,
            paint,
          );
        case CampaignParticles.confetti:
          final y = (s.y + t * (0.5 + 0.5 * s.size)) % 1;
          paint.color = confetti[i % confetti.length].withValues(alpha: 0.6);
          canvas
            ..save()
            ..translate(s.x * size.width, y * size.height)
            ..rotate(tau * (3 * t + s.phase))
            ..drawRect(const Rect.fromLTWH(-2, -3.5, 4, 7), paint)
            ..restore();
        case CampaignParticles.sparkle:
          final glow = 0.5 + 0.5 * math.sin(tau * (2 * t + s.phase));
          final r = 2 + 2 * s.size;
          final c = Offset(s.x * size.width, s.y * size.height);
          paint
            ..color = Colors.white.withValues(alpha: 0.15 + 0.5 * glow)
            ..strokeWidth = 1.2
            ..strokeCap = StrokeCap.round;
          canvas
            ..drawLine(c.translate(-r, 0), c.translate(r, 0), paint)
            ..drawLine(c.translate(0, -r), c.translate(0, r), paint);
        case CampaignParticles.none:
          return;
      }
    }
  }

  @override
  bool shouldRepaint(_ParticlesPainter old) =>
      old.kind != kind ||
      old.tint != tint ||
      old.count != count ||
      old.progress != progress;
}
