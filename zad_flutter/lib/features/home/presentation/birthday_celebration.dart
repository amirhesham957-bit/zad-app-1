/// The customer's own birthday: on the first open of the day, once a year, a
/// celebration over home — the cake, confetti, and a greeting by name.
///
/// The date is a memory note the brain wrote from the chat or from its
/// morning question (`remember_occasion`), read from the cached memory, so it
/// opens with no network. Not in a quiet period, like the occasion card: a
/// home in a hard few days gets no celebration (slice 29).
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
import 'package:zad/features/home/application/quiet_mode.dart';
import 'package:zad/shared/brain/application/memory_controller.dart';
import 'package:zad/shared/brain/domain/memory_occasion.dart';
import 'package:zad/shared/market/application/account_time_zone.dart';

/// The year today is the customer's birthday in, or null.
final ownBirthdayYearProvider = Provider<int?>((ref) {
  final zone = tz.getLocation(ref.watch(accountTimeZoneProvider));
  final local = tz.TZDateTime.from(ref.read(nowProvider)().toUtc(), zone);
  final today = DateTime(local.year, local.month, local.day);
  final remembered = ref.watch(
    memoryControllerProvider.select((v) => v.snapshot.occasions),
  );
  final own = remembered.any(
    (o) =>
        o.isOwn &&
        o.kind == MemoryOccasionKind.birthday &&
        o.daysFrom(today) == 0,
  );
  return own ? today.year : null;
});

/// The key a year's celebration is marked shown under.
String birthdaySeenKey(int year) => 'birthday_seen:$year';

/// Shows the celebration when it is due; draws nothing itself.
class BirthdayCelebration extends ConsumerStatefulWidget {
  /// Creates the host.
  const new({super.key});

  @override
  ConsumerState<BirthdayCelebration> createState() => _BirthdayState();
}

class _BirthdayState extends ConsumerState<BirthdayCelebration> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    ref
      ..listenManual<int?>(
        ownBirthdayYearProvider,
        (_, _) => _maybeShow(),
        fireImmediately: true,
      )
      // The quiet period is read from the server; decide once it is known.
      ..listenManual(quietModeProvider, (_, _) => _maybeShow());
  }

  bool _seen(int year) {
    try {
      return ref.read(localStoreProvider).device.get(birthdaySeenKey(year)) !=
          null;
    } on Object {
      return false; // No store (a test): show it.
    }
  }

  void _markSeen(int year) {
    try {
      unawaited(
        ref.read(localStoreProvider).device.put(birthdaySeenKey(year), 'seen'),
      );
    } on Object {
      // Shown again next open; better than not at all.
    }
  }

  void _maybeShow() {
    final year = ref.read(ownBirthdayYearProvider);
    if (_shown || year == null || _seen(year)) return;
    final quiet = ref.read(quietModeProvider);
    if (!quiet.hasValue || quiet.value != null) return;
    _shown = true;
    _markSeen(year);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final name = ref
          .read(memoryControllerProvider)
          .snapshot
          .profile
          ?.preferredName;
      unawaited(
        showDialog<void>(
          context: context,
          builder: (_) => BirthdayDialog(name: name),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// The celebration itself.
class BirthdayDialog extends StatelessWidget {
  /// Creates the dialog.
  const new({this.name, super.key});

  /// What the customer likes to be called, when زاد knows it.
  final String? name;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final who = name?.trim();
    return Dialog(
      backgroundColor: ZadColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZadRadii.cardLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ZadSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox.square(
              dimension: 160,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: Lottie.asset(
                      'assets/lottie/lottie_birthday_cake.json',
                      animate: !still,
                      errorBuilder: (_, _, _) => const Center(
                        child: Text('🎂', style: TextStyle(fontSize: 72)),
                      ),
                    ),
                  ),
                  if (!still)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Lottie.asset(
                          'assets/lottie/lottie_confetti_burst.json',
                          repeat: false,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: ZadSpacing.lg),
            Text(
              who == null || who.isEmpty
                  ? 'كل سنة وإنت طيب! 🎂'
                  : 'كل سنة وإنت طيب يا $who! 🎂',
              textAlign: TextAlign.center,
              style: ZadType.titleLarge,
            ),
            const SizedBox(height: ZadSpacing.sm),
            Text(
              'زاد بيتمنالك سنة حلوة مليانة خير وراحة بال.',
              textAlign: TextAlign.center,
              style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
            ),
            const SizedBox(height: ZadSpacing.xl),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('شكراً يا زاد 💚'),
            ),
          ],
        ),
      ),
    );
  }
}
