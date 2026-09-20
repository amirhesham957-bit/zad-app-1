/// The card that says whether bank messages are reaching the app.
///
/// It reports three states, and the middle one is why it exists: granted but
/// silent. A banner that only read the permission could not tell a working
/// channel from a dead one, and the ingest table stayed empty for weeks with
/// the switch showing on.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/design/components/zad_card.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/bank/application/bank_access_controller.dart';

/// Shows the bank channel's health, and the one action that repairs it.
class BankAccessCard extends ConsumerWidget {
  /// Creates the card.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bankAccessControllerProvider);
    final controller = ref.read(bankAccessControllerProvider.notifier);

    // Nothing to say while it is working and quiet. A permanent green tick for
    // something the user never asked about is noise on the one screen that has
    // to stay readable.
    if (state.health == BankAccessHealth.flowing) {
      return const SizedBox.shrink();
    }

    final (icon, accent, title, message, action) = switch (state.health) {
      BankAccessHealth.notGranted => (
        ZadIcons.pending,
        ZadColors.mustardOchre,
        'خلّي زاد يقرا رسايل البنك',
        'لما تسمح لزاد يشوف الإشعارات، هيسجّل مصاريفك من رسايل البنك من غير ما '
            'تكتب حاجة. زاد بيقرا الإشعار بس — مش بيبعت ولا بيكتب رسايل.',
        'افتح الإعدادات',
      ),
      BankAccessHealth.grantedButSilent => (
        ZadIcons.failed,
        ZadColors.terracottaRust,
        'السماح مفعّل، بس مفيش حاجة وصلت',
        'ساعات أندرويد بيوقف الخدمة بعد تحديث أو لما الذاكرة تضيق، والإذن '
            'بيفضل شكله شغال. جرّب تعيد التفعيل من الإعدادات.',
        'افتح الإعدادات',
      ),
      BankAccessHealth.flowing => (
        ZadIcons.synced,
        ZadColors.green600,
        '',
        '',
        '',
      ),
    };

    return ZadCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(ZadSpacing.sm),
                  child: Icon(icon, size: 20, color: accent),
                ),
              ),
              const SizedBox(width: ZadSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: ZadType.titleSmall.copyWith(color: ZadColors.ink),
                ),
              ),
              if (state.checking)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: ZadSpacing.md),
          Text(
            message,
            style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
          ),
          const SizedBox(height: ZadSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: controller.openSettings,
                  child: Text(action),
                ),
              ),
              const SizedBox(width: ZadSpacing.md),
              // Re-checking after the user comes back from system settings is
              // the whole loop: the app cannot be told when the switch moves.
              IconButton(
                onPressed: state.checking ? null : controller.refresh,
                icon: const Icon(ZadIcons.retry),
                tooltip: 'تحقق تاني',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
