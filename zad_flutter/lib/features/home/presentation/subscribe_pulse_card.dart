/// «اشترك» on home (ZAD_PLAN ٨ب.٣): a small breathing card for a free
/// customer, once a session, with a close. One tap opens the plans.
///
/// Shown only when the plan is known to be free — an unknown plan (offline,
/// signed out, an older server) shows nothing rather than selling a plan to
/// someone who may already pay. Never in kids mode: a child cannot buy. It
/// steps aside on the week the «شفت ١٥ إعلان» card is up, so home never
/// carries two pitches at once.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/components/zad_pulses.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_motion.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/auth/application/session_controller.dart';
import 'package:zad/shared/kids/application/kids_mode_controller.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/quota/application/attempts_balance_provider.dart';
import 'package:zad/shared/quota/data/ad_week_remote.dart';

/// Whether the card is done for this session — closed, or tapped through.
/// Held in memory on purpose: the next session shows it again.
class SubscribePulseDone extends Notifier<bool> {
  @override
  bool build() => false;

  /// Hides the card until the app is started again.
  void done() => state = true;
}

/// The session's flag.
final subscribePulseDoneProvider = NotifierProvider<SubscribePulseDone, bool>(
  SubscribePulseDone.new,
);

/// Whether home shows the card now.
final subscribePulseVisibleProvider = Provider<bool>((ref) {
  if (ref.watch(subscribePulseDoneProvider)) return false;
  if (ref.watch(sessionControllerProvider) == null) return false;
  if (ref.watch(kidsModeActiveProvider)) return false;
  if (ref.watch(attemptsBalanceProvider).value?.isFree != true) return false;
  // Waits for the week's answer, so the card does not flash in and out.
  final week = ref.watch(adWeekProvider);
  return week.hasValue && week.value == null;
});

/// The card, or nothing.
class SubscribePulseCard extends ConsumerWidget {
  /// Creates it.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(subscribePulseVisibleProvider);
    return AnimatedSize(
      duration: ZadDuration.enter,
      curve: ZadCurves.standard,
      child: visible
          ? const Padding(
              padding: EdgeInsets.only(bottom: ZadSpacing.lg),
              child: _Card(),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

class _Card extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final still = MediaQuery.disableAnimationsOf(context);
    final star = Icon(
      Icons.workspace_premium_rounded,
      size: 28,
      color: ZadColors.mustardOchre,
    );

    void open() {
      ref.read(subscribePulseDoneProvider.notifier).done();
      unawaited(ZadScreens.showPaywallScreen(context));
    }

    return Material(
      color: ZadColors.mint50,
      borderRadius: BorderRadius.circular(ZadRadii.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: open,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            ZadSpacing.lg,
            ZadSpacing.md,
            ZadSpacing.xs,
            ZadSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              if (still) star else ZadDotPulse(child: star),
              const SizedBox(width: ZadSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.subscribePulseTitle,
                      style: ZadType.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: ZadSpacing.xs),
                    Text(
                      l10n.subscribePulseBody,
                      style: ZadType.bodyMedium.copyWith(
                        color: ZadColors.slate,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () =>
                    ref.read(subscribePulseDoneProvider.notifier).done(),
                icon: const Icon(Icons.close_rounded, size: 20),
                color: ZadColors.inkMuted,
                tooltip: l10n.subscribePulseClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
