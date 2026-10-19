/// رفيق زاد on the subscription screen (ZAD_PLAN ٥.٢): it knows where it is
/// and says so, once, without pressing. Nothing when there is no pet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/companion/application/companion_controller.dart';
import 'package:zad/shared/companion/application/pet_care_controller.dart';
import 'package:zad/shared/companion/domain/fourth_wall.dart';
import 'package:zad/shared/companion/domain/pet_care.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';

/// The pet beside the plans, with one line about the screen it is on.
class CompanionPaywallAside extends ConsumerStatefulWidget {
  /// Creates it.
  const new({super.key});

  @override
  ConsumerState<CompanionPaywallAside> createState() =>
      _CompanionPaywallAsideState();
}

class _CompanionPaywallAsideState extends ConsumerState<CompanionPaywallAside> {
  String? _line;

  @override
  Widget build(BuildContext context) {
    final PetCare? care;
    try {
      care = ref.watch(petCareProvider);
    } on Object {
      return const SizedBox.shrink(); // No store (a test host).
    }
    if (care == null) return const SizedBox.shrink();
    final name = ref.watch(companionProvider).value?.persona.name ?? 'زادو';
    final line = _line ??= FourthWall.paywall(name: name);
    return Padding(
      padding: const EdgeInsets.only(bottom: ZadSpacing.md),
      child: Row(
        key: const ValueKey<String>('paywall-pet'),
        children: <Widget>[
          const CompanionOrb(size: 48),
          const SizedBox(width: ZadSpacing.sm),
          Expanded(
            child: Text(
              line,
              style: ZadType.bodyMedium.copyWith(color: ZadColors.slate),
            ),
          ),
        ],
      ),
    );
  }
}
