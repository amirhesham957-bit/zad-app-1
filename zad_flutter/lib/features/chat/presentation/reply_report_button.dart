/// The flag under each of Zad's replies, and the sheet it opens
/// (ZAD_PLAN 8.3).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/chat/application/reply_report.dart';
import 'package:zad/shared/chat/domain/chat_message.dart';

/// Reports [message], one of Zad's replies.
class ReplyReportButton extends ConsumerWidget {
  /// Creates the button.
  const new({required this.message, super.key});

  /// The reply it reports.
  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    tooltip: context.l10n.chatReport,
    onPressed: () => unawaited(_report(context, ref)),
    icon: Icon(ZadIcons.report, size: 20, color: ZadColors.inkMuted),
  );

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final reason = await showModalBottomSheet<ReplyReportReason>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _ReasonSheet(),
    );
    if (reason == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = context.l10n;
    final ok = await ref.read(replyReporterProvider)(
      messageId: message.id,
      text: message.text,
      reason: reason,
    );
    if (ok) unawaited(HapticFeedback.lightImpact());
    messenger?.showSnackBar(
      SnackBar(content: Text(ok ? l.chatReportSent : l.chatReportFailed)),
    );
  }
}

class _ReasonSheet extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final reasons = <(ReplyReportReason, String)>[
      (ReplyReportReason.offensive, l.chatReportOffensive),
      (ReplyReportReason.wrong, l.chatReportWrong),
      (ReplyReportReason.harmful, l.chatReportHarmful),
      (ReplyReportReason.other, l.chatReportOther),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: ZadSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.xl),
              child: Text(l.chatReportTitle, style: ZadType.titleMedium),
            ),
            const SizedBox(height: ZadSpacing.sm),
            for (final (reason, label) in reasons)
              ListTile(
                minTileHeight: 48,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: ZadSpacing.xl,
                ),
                title: Text(label, style: ZadType.bodyLarge),
                onTap: () => Navigator.of(context).pop(reason),
              ),
          ],
        ),
      ),
    );
  }
}
