/// The conversation with زاد.
///
/// The composer never waits on the server. What the customer typed is on
/// screen and in the box before the request goes out, and an empty reply
/// bubble appears underneath it straight away so the wait has a shape.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/foundation/squircle.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/chat/application/chat_controller.dart';
import 'package:zad/features/chat/domain/agent_turn.dart';
import 'package:zad/features/chat/domain/chat_message.dart';

/// The chat screen.
class ChatScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    // Cleared here, not after the reply. The message is saved the moment the
    // controller takes it, so leaving it in the field would only offer the
    // customer the chance to send it twice.
    _composer.clear();
    setState(() {});
    await ref.read(chatControllerProvider.notifier).send(text);
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(chatControllerProvider);

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('زاد'),
          actions: <Widget>[
            if (!view.isEmpty)
              IconButton(
                onPressed: () => _confirmClear(context),
                icon: const Icon(ZadIcons.dismiss),
                tooltip: 'ابدأ محادثة جديدة',
              ),
          ],
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: view.isEmpty
                  ? const _Welcome()
                  : ListView.builder(
                      controller: _scroll,
                      // Reversed, so a new message lands at the visually
                      // bottom without anyone having to animate a scroll to
                      // it — and so the keyboard opening does not push the
                      // conversation out of view.
                      reverse: true,
                      padding: const EdgeInsets.all(ZadSpacing.gutter),
                      itemCount: view.messages.length,
                      itemBuilder: (_, i) => _Bubble(
                        message: view.messages[view.messages.length - 1 - i],
                      ),
                    ),
            ),
            _Composer(
              controller: _composer,
              busy: view.isAwaitingReply,
              onChanged: () => setState(() {}),
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تبدأ محادثة جديدة؟'),
        content: const Text(
          // Said plainly, because it is not obvious: what زاد knows about the
          // customer lives on the server and survives this. Only the
          // scrollback on this phone goes.
          'الكلام اللي فات هيتمسح من التليفون ده. اللي زاد اتعلمه عنك '
          'هيفضل زي ما هو.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('استنى'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('امسح'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(chatControllerProvider.notifier).clear();
    }
  }
}

class _Welcome extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const ZadEmptyState(
    icon: ZadIcons.assistant,
    title: 'اسألني عن فلوسك',
    message:
        'اكتب زي ما بتتكلم — "صرفت ٥٠ قهوة"، "أقدر أشتري كوتشي بـ٤٠٠؟"، '
        '"ميزانيتي عاملة إيه؟"',
  );
}

/// One message.
class _Bubble extends ConsumerWidget {
  const new({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = message.isUser;
    final failed = message.status == ChatStatus.failed;

    return Padding(
      padding: const EdgeInsets.only(bottom: ZadSpacing.md),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: <Widget>[
          Row(
            mainAxisAlignment: mine
                ? MainAxisAlignment.start
                : MainAxisAlignment.end,
            children: <Widget>[
              Flexible(
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: mine ? ZadColors.green800 : ZadColors.surface,
                    shape: zadSquircle(
                      ZadRadii.cardLarge,
                      side: mine
                          ? BorderSide.none
                          : const BorderSide(
                              color: ZadColors.hairline,
                              width: 0.5,
                            ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ZadSpacing.lg,
                      vertical: ZadSpacing.md,
                    ),
                    child: message.isStreaming && message.text.isEmpty
                        ? const _Thinking()
                        : Text(
                            message.text,
                            style: ZadType.bodyLarge.copyWith(
                              color: mine ? Colors.white : ZadColors.ink,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),

          if (message.specialist case final specialist?) ...<Widget>[
            const SizedBox(height: ZadSpacing.xs),
            Text(
              specialist,
              style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
            ),
          ],

          // Receipts for what the server already did, not buttons. The write
          // has happened; this is the record of it.
          for (final receipt in message.executed) _Receipt(receipt: receipt),

          // And the opposite: nothing has happened yet.
          for (final proposal in message.proposals)
            _Proposal(messageId: message.id, proposal: proposal),

          if (failed && mine) ...<Widget>[
            const SizedBox(height: ZadSpacing.xs),
            TextButton.icon(
              onPressed: () =>
                  ref.read(chatControllerProvider.notifier).retry(message.id),
              icon: const Icon(ZadIcons.retry, size: 16),
              label: const Text('ماوصلتش — ابعتها تاني'),
              style: TextButton.styleFrom(
                foregroundColor: ZadColors.terracottaRust,
                textStyle: ZadType.labelSmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      const SizedBox(width: ZadSpacing.sm),
      Text(
        'بفكر…',
        style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
      ),
    ],
  );
}

/// Something the server did.
class _Receipt extends StatelessWidget {
  const new({required this.receipt});

  final AgentExecuted receipt;

  @override
  Widget build(BuildContext context) {
    final accent = receipt.ok ? ZadColors.green600 : ZadColors.terracottaRust;

    return Padding(
      padding: const EdgeInsets.only(top: ZadSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Flexible(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: accent.withValues(alpha: 0.08),
                shape: zadSquircle(ZadRadii.chip),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ZadSpacing.md,
                  vertical: ZadSpacing.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      receipt.ok ? ZadIcons.synced : ZadIcons.failed,
                      size: 14,
                      color: accent,
                    ),
                    const SizedBox(width: ZadSpacing.sm),
                    Flexible(
                      child: Text(
                        receipt.summary,
                        style: ZadType.labelMedium.copyWith(
                          color: ZadColors.slate,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Something the server is waiting to be allowed to do.
class _Proposal extends ConsumerWidget {
  const new({required this.messageId, required this.proposal});

  final String messageId;
  final AgentProposal proposal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(
      chatControllerProvider.select(
        (v) => v.confirming.contains(proposal.tool),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: ZadSpacing.sm),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: ZadColors.mint50,
          shape: zadSquircle(ZadRadii.chip),
        ),
        child: Padding(
          padding: const EdgeInsets.all(ZadSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                proposal.summary.isEmpty ? proposal.tool : proposal.summary,
                style: ZadType.bodySmall.copyWith(color: ZadColors.slate),
              ),
              const SizedBox(height: ZadSpacing.xs),
              Text(
                'لسه ماتنفذش.',
                style: ZadType.labelSmall.copyWith(
                  color: ZadColors.mustardOchre,
                ),
              ),
              const SizedBox(height: ZadSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton(
                      onPressed: busy
                          ? null
                          : () {
                              unawaited(HapticFeedback.mediumImpact());
                              unawaited(
                                ref
                                    .read(chatControllerProvider.notifier)
                                    .confirm(messageId, proposal),
                              );
                            },
                      child: const Text('اعملها'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const new({
    required this.controller,
    required this.busy,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onChanged;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    final canSend = !busy && controller.text.trim().isNotEmpty;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(ZadSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onChanged: (_) => onChanged(),
                onSubmitted: (_) => canSend ? onSend() : null,
                decoration: const InputDecoration(
                  hintText: 'اكتب لزاد…',
                  filled: true,
                  fillColor: ZadColors.surface,
                ),
              ),
            ),
            const SizedBox(width: ZadSpacing.sm),
            // Big enough to hit, in the bottom third, where the thumb is.
            SizedBox(
              width: kZadMinTapTarget,
              height: kZadMinTapTarget,
              child: IconButton.filled(
                onPressed: canSend ? onSend : null,
                icon: const Icon(ZadIcons.forward, size: 20),
                tooltip: 'ابعت',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
