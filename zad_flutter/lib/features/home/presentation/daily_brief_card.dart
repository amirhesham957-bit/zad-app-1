/// «موجز زاد النهارده» — the top of زاد's home (daily_brief.dart).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/shared/brain/presentation/daily_brief_lines.dart';
import 'package:zad/shared/navigation/shell_navigation.dart';

/// The card.
class DailyBriefCard extends ConsumerWidget {
  /// Creates the card.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open(ShellTab tab) =>
        ref.read(shellNavigationProvider.notifier).open(tab);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ZadColors.surface,
        borderRadius: BorderRadius.circular(ZadRadii.card),
        border: Border.all(color: ZadColors.outline.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ZadSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(ZadIcons.brain, color: ZadColors.forestEmerald),
                const SizedBox(width: ZadSpacing.sm),
                Expanded(
                  child: Text(
                    'موجز زاد النهارده',
                    style: ZadType.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => open(ShellTab.assistant),
                  child: const Text('عقل زاد'),
                ),
              ],
            ),
            const SizedBox(height: ZadSpacing.sm),
            DailyBriefLines(
              empty: Text(
                'كله تمام — مفيش حاجة مستعجلة النهارده.',
                style: ZadType.bodyMedium.copyWith(color: ZadColors.inkMuted),
              ),
            ),
            const SizedBox(height: ZadSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => open(ShellTab.chat),
              icon: const Icon(ZadIcons.assistant, size: 18),
              label: const Text('اسأل زاد عن أي حاجة'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
