/// The occasion on every screen (ZAD_PLAN ٨ب.٤): the shared header takes a
/// wash of the occasion's colours and a few of its particles, so a winter
/// week or the Eid shows on the pantry and the chat too, not only on Home.
///
/// Quiet: low count, a faint wash, drawn behind the header's controls. A
/// quiet period (slice 29) has no campaign, so no layer; the phone's «remove
/// animations» freezes the particles.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/features/home/application/home_campaign.dart';
import 'package:zad/features/home/presentation/campaign_banner.dart';
import 'package:zad/shared/campaigns/domain/campaign.dart';

/// The layer, or nothing on a day without an occasion.
class SeasonHeaderLayer extends ConsumerWidget {
  /// Creates it.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(homeCampaignProvider);
    if (active == null) return const SizedBox.shrink();
    final c = active.campaign;
    final primary = Color(c.primary);
    final secondary = Color(c.secondary);
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return IgnorePointer(
      child: Stack(
        key: ValueKey<String>('season-header-${c.eventKey}'),
        fit: StackFit.expand,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: <Color>[
                  primary.withValues(alpha: 0.14),
                  secondary.withValues(alpha: 0.06),
                  secondary.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          if (c.particles != CampaignParticles.none)
            CampaignParticlesLayer(
              kind: c.particles,
              tint: primary,
              // The header is everywhere: a season day stays sparse, the
              // occasion's own days a little fuller.
              intensity: active.intensity == CampaignIntensity.peak
                  ? CampaignIntensity.medium
                  : CampaignIntensity.low,
              still: still,
              ink: Color.lerp(primary, Colors.white, 0.25),
            ),
        ],
      ),
    );
  }
}
