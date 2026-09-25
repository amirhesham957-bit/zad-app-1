/// "من زاد" on Home: what the brain noticed, at most three cards, each one
/// dismissible with a reason or — for a question — answerable.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/design/components/zad_card.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/insights/application/insights_controller.dart';
import 'package:zad/features/insights/domain/insight.dart';

/// The section. Renders nothing when there is nothing pending — Home is for
/// the money first.
class HomeInsightsSection extends ConsumerWidget {
  /// Creates the section.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(insightsControllerProvider.select((v) => v.onHome));
    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(bottom: ZadSpacing.sm),
          child: Text('من زاد', style: ZadType.titleSmall),
        ),
        for (final i in cards) ...<Widget>[
          _InsightCard(insight: i),
          const SizedBox(height: ZadSpacing.sm),
        ],
      ],
    );
  }
}

class _InsightCard extends ConsumerWidget {
  const new({required this.insight});

  final ZadInsight insight;

  Future<void> _dismiss(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(insightsControllerProvider.notifier);
    if (insight.isQuestion) {
      // A question put off has no reason to give; it is not a verdict on the
      // brain.
      await controller.dismiss(insight);
      return;
    }
    final reason = await showModalBottomSheet<DismissReason>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(
                ZadSpacing.gutter,
                0,
                ZadSpacing.gutter,
                ZadSpacing.sm,
              ),
              child: Text(
                'ليه مش عايزه؟ زاد هيتعلم من ده',
                style: ZadType.titleSmall,
              ),
            ),
            for (final r in DismissReason.values)
              ListTile(
                title: Text(r.label),
                onTap: () => Navigator.of(sheetContext).pop(r),
              ),
            const SizedBox(height: ZadSpacing.sm),
          ],
        ),
      ),
    );
    if (reason == null) return;
    await controller.dismiss(insight, reason: reason);
  }

  Future<void> _answer(BuildContext context, WidgetRef ref) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _AnswerDialog(question: insight),
    );
    if (text == null || text.trim().isEmpty) return;
    await ref.read(insightsControllerProvider.notifier).answer(insight, text);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = insight.isCritical
        ? ZadColors.terracottaRust
        : ZadColors.green600;
    return ZadCard(
      padding: const EdgeInsets.fromLTRB(
        ZadSpacing.xs,
        ZadSpacing.md,
        ZadSpacing.lg,
        ZadSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: ZadSpacing.xs + 2),
            child: DecoratedBox(
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              child: const SizedBox.square(dimension: 10),
            ),
          ),
          const SizedBox(width: ZadSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(insight.title, style: ZadType.titleSmall),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(ZadSpacing.lg),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: ZadSpacing.sm,
                          vertical: 2,
                        ),
                        child: Text(
                          insight.kindLabel,
                          style: ZadType.labelSmall.copyWith(color: accent),
                        ),
                      ),
                    ),
                  ],
                ),
                if (insight.body.isNotEmpty) ...<Widget>[
                  const SizedBox(height: ZadSpacing.xs),
                  Text(
                    insight.body,
                    style: ZadType.bodySmall.copyWith(color: ZadColors.slate),
                  ),
                ],
                if (insight.isQuestion)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: () => _answer(context, ref),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                      child: const Text('جاوب'),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => unawaited(_dismiss(context, ref)),
            tooltip: insight.isQuestion ? 'مش دلوقتي' : 'اقفل',
            icon: const Icon(ZadIcons.dismiss, size: 18),
          ),
        ],
      ),
    );
  }
}

class _AnswerDialog extends StatefulWidget {
  const new({required this.question});

  final ZadInsight question;

  @override
  State<_AnswerDialog> createState() => _AnswerDialogState();
}

class _AnswerDialogState extends State<_AnswerDialog> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.question.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.question.body.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: ZadSpacing.md),
            child: Text(widget.question.body),
          ),
        TextField(
          controller: _text,
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'ردّك'),
        ),
      ],
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('استنى'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(_text.text),
        child: const Text('ابعت لزاد'),
      ),
    ],
  );
}
