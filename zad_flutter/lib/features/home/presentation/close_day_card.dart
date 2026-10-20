/// «اقفل يومك» on home (ZAD_PLAN ٣.٢): from 8 in the evening on the account's
/// clock until the day is closed. The same close the 9:30 message and its
/// Telegram buttons make; one tap opens the sheet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/components/zad_card.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/day_close/application/day_close_controller.dart';
import 'package:zad/shared/day_close/presentation/close_day_sheet.dart';

/// The hour (account clock) the card starts showing.
const int kCloseDayFromHour = 20;

/// The card, or nothing outside the evening or once the day is closed.
class CloseDayCard extends ConsumerWidget {
  /// Creates the card.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final closed = ref.watch(dayCloseProvider);
    final controller = ref.read(dayCloseProvider.notifier);
    if (closed == controller.today() ||
        controller.hourNow() < kCloseDayFromHour) {
      return const SizedBox.shrink();
    }
    return ZadCard(
      onTap: () => showCloseDaySheet(context, ref),
      child: Row(
        children: <Widget>[
          const Text('🌙', style: ZadType.titleMedium),
          const SizedBox(width: ZadSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.homeCloseDay,
                  style: ZadType.titleSmall.copyWith(color: ZadColors.ink),
                ),
                const SizedBox(height: ZadSpacing.xs),
                Text(
                  context.l10n.homeCloseDayHint,
                  style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
                ),
              ],
            ),
          ),
          Icon(ZadIcons.forward, size: 18, color: ZadColors.inkMuted),
        ],
      ),
    );
  }
}
