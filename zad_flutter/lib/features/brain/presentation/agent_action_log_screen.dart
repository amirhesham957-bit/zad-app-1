/// "سجل تعديلات زاد": what زاد changed, in words, with a way back.
///
/// The actions already happened — the agent's write tools run on the server —
/// so this is the transparency line after the fact: see exactly what was
/// touched, and take it back if it was wrong.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/core/period/account_time_zone.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/components/zad_card.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/brain/application/agent_actions_controller.dart';
import 'package:zad/features/brain/data/agent_actions_repository.dart';
import 'package:zad/features/brain/domain/agent_action.dart';
import 'package:zad/features/notifications/presentation/notification_center_screen.dart'
    show whenLabel;

/// Opens the log.
Future<void> showAgentActionLog(BuildContext context) => Navigator.of(context)
    .push<void>(
      MaterialPageRoute<void>(builder: (_) => const AgentActionLogScreen()),
    );

/// The log.
class AgentActionLogScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<AgentActionLogScreen> createState() =>
      _AgentActionLogScreenState();
}

class _AgentActionLogScreenState extends ConsumerState<AgentActionLogScreen> {
  @override
  void initState() {
    super.initState();
    // Every open reads the log again: it is a database read, and the actions
    // most worth seeing are the ones the chat just made.
    // After this frame: a refresh changes provider state, which is not
    // allowed while the tree is building.
    unawaited(
      Future<void>.microtask(
        () => mounted
            ? ref.read(agentActionsControllerProvider.notifier).refresh()
            : null,
      ),
    );
  }

  Future<void> _undo(AgentAction action) async {
    // Asked first: undoing an "add" deletes the row, and there is no undo of
    // an undo on the server.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('ترجع في «${agentToolLabel(action.toolName)}»؟'),
        content: const Text(
          'زاد هيرجّع الحاجة دي زي ما كانت قبل التعديل. مش هتقدر ترجع في '
          'الرجوع ده بعدين.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('استنى'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ارجع فيه'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !mounted) return;

    final outcome = await ref
        .read(agentActionsControllerProvider.notifier)
        .undo(action);
    if (outcome == null || !mounted) return;
    final message = switch (outcome) {
      Undone() => 'رجعت في «${agentToolLabel(action.toolName)}»',
      UndoRefused(:final failure) => failure.message,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(agentActionsControllerProvider);
    final now = ref.read(nowProvider)();
    final zone = ref.read(accountTimeZoneProvider);

    return DecoratedBox(
      decoration: BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('سجل تعديلات زاد')),
        body: RefreshIndicator(
          onRefresh: ref.read(agentActionsControllerProvider.notifier).refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              if (view.items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: view.isRefreshing
                      ? const Center(child: CircularProgressIndicator())
                      : ZadEmptyState(
                          icon: view.error != null
                              ? ZadIcons.failed
                              : ZadIcons.actionLog,
                          title: view.error != null
                              ? 'مقدرتش أجيب السجل'
                              : 'لسه مفيش تعديلات',
                          message: view.error != null
                              ? 'اسحب لتحت نجرب تاني.'
                              : 'أي حاجة زاد يسجّلها أو يعدّلها لك هتظهر هنا.',
                          tone: view.error != null
                              ? ZadEmptyTone.problem
                              : ZadEmptyTone.calm,
                        ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(ZadSpacing.gutter),
                  sliver: SliverList.separated(
                    itemCount: view.items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: ZadSpacing.sm),
                    itemBuilder: (context, i) {
                      final action = view.items[i];
                      return _ActionCard(
                        action: action,
                        when: whenLabel(action.createdAt, now, zone),
                        undoing: view.undoingId == action.id,
                        // Only one undo at a time: the next one may depend on
                        // this one landing first.
                        onUndo: action.isUndoable && view.undoingId == null
                            ? () => _undo(action)
                            : null,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const new({
    required this.action,
    required this.when,
    required this.undoing,
    required this.onUndo,
  });

  final AgentAction action;
  final String when;
  final bool undoing;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final (statusText, statusColor) = switch (action.status) {
      'applied' => ('اتنفذ', ZadColors.green700),
      'undone' => ('اترجع فيه', ZadColors.inkMuted),
      'rejected' => ('اترفض', ZadColors.terracottaRust),
      _ => ('', ZadColors.inkMuted),
    };
    final summary = action.resultSummary?.trim() ?? '';

    return ZadCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      agentToolLabel(action.toolName),
                      style: ZadType.titleSmall,
                    ),
                    const SizedBox(height: ZadSpacing.xs),
                    Text(
                      '${agentSourceLabel(action.source)} · $when',
                      style: ZadType.labelSmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (statusText.isNotEmpty)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(ZadSpacing.lg),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ZadSpacing.sm + 2,
                      vertical: ZadSpacing.xs,
                    ),
                    child: Text(
                      statusText,
                      style: ZadType.labelSmall.copyWith(color: statusColor),
                    ),
                  ),
                ),
            ],
          ),
          if (summary.isNotEmpty) ...<Widget>[
            const SizedBox(height: ZadSpacing.sm),
            Text(
              summary,
              style: ZadType.bodySmall.copyWith(color: ZadColors.slate),
            ),
          ],
          if (action.isUndoable) ...<Widget>[
            const SizedBox(height: ZadSpacing.md),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OutlinedButton.icon(
                onPressed: onUndo,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                icon: undoing
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(ZadIcons.undo, size: 16),
                label: const Text('ارجع فيه'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
