/// The occasion card: on the first open of an occasion's day — New Year,
/// Ramadan, the two Eids, the Hijri new year, Mother's Day — a short
/// celebration and one thing زاد offers to do, done in one tap
/// (docs/agent/ZAD_LIVING_BRAIN.md slice 22).
///
/// The tap sends the request to the brain and opens the chat on its answer;
/// the brain's tools still ask before anything touches money. Shown once per
/// occasion: acting or «مش دلوقتي» puts it away until the next one.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/brain/domain/occasion.dart';
import 'package:zad/shared/chat/application/chat_controller.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';
import 'package:zad/shared/navigation/zad_slots.dart';
import 'package:zad/shared/settings/data/settings_repository.dart';

/// Today's occasion on the account's calendar, or null.
final occasionTodayProvider = Provider<Occasion?>((ref) {
  final zone = tz.getLocation(ref.watch(accountTimeZoneProvider));
  final local = tz.TZDateTime.from(ref.read(nowProvider)().toUtc(), zone);
  final country = ref.watch(settingsRepositoryProvider).cached()?.country;
  return occasionOn(
    DateTime(local.year, local.month, local.day),
    country: country,
  );
});

/// The key an occasion is put away under.
String occasionDoneKey(Occasion o) => 'occasion_done:${o.id}';

/// The card, or nothing.
class OccasionCardSlot extends ConsumerStatefulWidget {
  /// Creates the slot.
  const new({super.key});

  @override
  ConsumerState<OccasionCardSlot> createState() => _OccasionCardSlotState();
}

class _OccasionCardSlotState extends ConsumerState<OccasionCardSlot> {
  final Set<String> _done = <String>{};

  bool _isDone(Occasion o) {
    if (_done.contains(o.id)) return true;
    try {
      return ref.read(localStoreProvider).device.get(occasionDoneKey(o)) !=
          null;
    } on Object {
      return false; // No store (a test): show it.
    }
  }

  void _putAway(Occasion o) {
    setState(() => _done.add(o.id));
    try {
      unawaited(
        ref.read(localStoreProvider).device.put(occasionDoneKey(o), 'done'),
      );
    } on Object {
      // Shown again next open; better than not at all.
    }
  }

  void _act(Occasion o) {
    _putAway(o);
    unawaited(ref.read(chatControllerProvider.notifier).send(o.prompt));
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => ZadSlots.chatScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = ref.watch(occasionTodayProvider);
    if (o == null || _isDone(o)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: ZadSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(ZadSpacing.lg),
        decoration: BoxDecoration(
          color: ZadColors.mint50,
          borderRadius: BorderRadius.circular(ZadRadii.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                SizedBox.square(
                  dimension: 56,
                  child: Lottie.asset(
                    'assets/lottie/lottie_confetti_burst.json',
                    repeat: false,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: ZadSpacing.md),
                Expanded(child: Text(o.title, style: ZadType.titleMedium)),
              ],
            ),
            const SizedBox(height: ZadSpacing.sm),
            Text(
              o.question,
              style: ZadType.bodyMedium.copyWith(color: ZadColors.ink),
            ),
            const SizedBox(height: ZadSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: () => _act(o),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(o.actionLabel),
                  ),
                ),
                const SizedBox(width: ZadSpacing.md),
                TextButton(
                  onPressed: () => _putAway(o),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                  child: const Text('مش دلوقتي'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
