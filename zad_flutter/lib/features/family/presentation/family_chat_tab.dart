/// Kotlin's family `ChatTab`: who is online, the conversation with its date
/// separators, the four bubble kinds (text, SOS, purchase request, poll), pin
/// and reactions, quick replies, and the action strip — SOS, a money request,
/// a poll, a task, a grocery — beside the composer.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/components/zad_empty_state.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/family/application/family_life_controller.dart';
import 'package:zad/features/family/domain/family.dart';
import 'package:zad/features/family/domain/family_life.dart';
import 'package:zad/features/family/presentation/family_dialogs.dart';

/// The chat.
class FamilyChatTab extends ConsumerStatefulWidget {
  /// Creates the tab.
  const new({required this.family, required this.me, super.key});

  /// The family.
  final Family family;

  /// The signed-in member.
  final FamilyMember me;

  @override
  ConsumerState<FamilyChatTab> createState() => _FamilyChatTabState();
}

class _FamilyChatTabState extends ConsumerState<FamilyChatTab> {
  final TextEditingController _text = TextEditingController();
  bool _quickReplies = false;
  String? _pickerFor;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = preset ?? _text.text;
    if (text.trim().isEmpty) return;
    if (preset == null) _text.clear();
    setState(() => _quickReplies = false);
    await ref.read(familyLifeControllerProvider.notifier).send(text);
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(familyLifeControllerProvider);
    final now = ref.read(nowProvider)();
    final members = widget.family.members;
    final online = <FamilyMember>[
      for (final m in members)
        if (m.id != widget.me.id && m.isOnlineAt(now)) m,
    ];
    final messages = view.messages.reversed.toList();

    return Column(
      children: <Widget>[
        if (online.isNotEmpty)
          Container(
            width: double.infinity,
            color: ZadColors.green700.withValues(alpha: 0.05),
            padding: const EdgeInsets.symmetric(
              horizontal: ZadSpacing.lg,
              vertical: 6,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (final m in online) ...<Widget>[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: ZadColors.green600,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: ZadSpacing.xs),
                    Text(
                      m.alias,
                      style: ZadType.labelSmall.copyWith(
                        color: ZadColors.inkMuted,
                      ),
                    ),
                    const SizedBox(width: ZadSpacing.sm),
                  ],
                ],
              ),
            ),
          ),
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: ZadEmptyState(
                    icon: ZadIcons.ask,
                    title: 'لا توجد رسائل بعد',
                    message: 'ابدأ المحادثة بإرسال أول رسالة لعائلتك',
                    action: Wrap(
                      spacing: ZadSpacing.sm,
                      alignment: WrapAlignment.center,
                      children: <Widget>[
                        ActionChip(
                          avatar: const Icon(ZadIcons.chore, size: 16),
                          label: const Text('أضف مهام'),
                          onPressed: () => unawaited(
                            showQuickTaskDialog(
                              context,
                              ref,
                              members,
                              widget.me,
                            ),
                          ),
                        ),
                        ActionChip(
                          avatar: const Icon(ZadIcons.shopping, size: 16),
                          label: const Text('اطلب بقالة'),
                          onPressed: () =>
                              unawaited(showQuickGroceryDialog(context, ref)),
                        ),
                        ActionChip(
                          avatar: const Icon(ZadIcons.assistant, size: 16),
                          label: const Text('استشر @Zad'),
                          onPressed: () => setState(() {
                            _text.text = '@Zad ';
                            _text.selection = TextSelection.collapsed(
                              offset: _text.text.length,
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZadSpacing.lg,
                    vertical: ZadSpacing.lg,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    final day = _dayOf(msg.createdAt);
                    final olderDay = i + 1 < messages.length
                        ? _dayOf(messages[i + 1].createdAt)
                        : null;
                    return Column(
                      children: <Widget>[
                        if (day != null && day != olderDay)
                          _DateChip(day: day, now: now),
                        _MessageRow(
                          message: msg,
                          members: members,
                          me: widget.me,
                          pickerOpen: _pickerFor == msg.id,
                          onTogglePicker: () => setState(
                            () => _pickerFor = _pickerFor == msg.id
                                ? null
                                : msg.id,
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
        _Composer(
          text: _text,
          quickReplies: _quickReplies,
          onToggleQuickReplies: () =>
              setState(() => _quickReplies = !_quickReplies),
          onQuickReply: (r) => unawaited(_send(r)),
          onSend: () => unawaited(_send()),
          onSos: () => unawaited(confirmAndSendSos(context, ref)),
          onRequest: () => unawaited(showPurchaseRequestDialog(context, ref)),
          onPoll: () => unawaited(showPollDialog(context, ref)),
          onTask: () =>
              unawaited(showQuickTaskDialog(context, ref, members, widget.me)),
          onGrocery: () => unawaited(showQuickGroceryDialog(context, ref)),
        ),
      ],
    );
  }

  static DateTime? _dayOf(DateTime? at) {
    if (at == null) return null;
    final local = at.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}

class _DateChip extends StatelessWidget {
  const new({required this.day, required this.now});

  final DateTime day;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final today = DateTime(now.year, now.month, now.day);
    final label = day == today
        ? 'اليوم'
        : day == today.subtract(const Duration(days: 1))
        ? 'أمس'
        : '${day.year}/${day.month.toString().padLeft(2, '0')}/'
              '${day.day.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ZadSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ZadSpacing.md,
          vertical: ZadSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: ZadColors.ink.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
        ),
      ),
    );
  }
}

String _share(int count, int total) =>
    '$count (${(count * 100 / total).round()}%)';

String _time(DateTime? at) {
  if (at == null) return '';
  final l = at.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:'
      '${l.minute.toString().padLeft(2, '0')}';
}

class _MessageRow extends ConsumerWidget {
  const new({
    required this.message,
    required this.members,
    required this.me,
    required this.pickerOpen,
    required this.onTogglePicker,
  });

  final FamilyMessage message;
  final List<FamilyMember> members;
  final FamilyMember me;
  final bool pickerOpen;
  final VoidCallback onTogglePicker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMe = message.senderId == me.id;
    final isAi = message.isFromZad;
    final alias =
        members.where((m) => m.id == message.senderId).firstOrNull?.alias ??
        'Zad AI';
    final bubble = switch (message.type) {
      FamilyMessageType.sos => _SosBubble(message: message, alias: alias),
      FamilyMessageType.purchaseRequest => _RequestBubble(
        message: message,
        alias: alias,
        canDecide: me.role == FamilyRole.admin && !isMe,
      ),
      FamilyMessageType.poll => _PollBubble(
        message: message,
        alias: alias,
        myId: me.id,
      ),
      FamilyMessageType.text => _TextBubble(
        message: message,
        alias: alias,
        isMe: isMe,
        isAi: isAi,
        pickerOpen: pickerOpen,
        onTogglePicker: onTogglePicker,
      ),
    };
    final reactions = message.reactionCounts;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!isMe && !isAi) ...<Widget>[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: ZadColors.green700.withValues(alpha: 0.2),
                  child: Text(
                    alias.characters.firstOrNull ?? '?',
                    style: ZadType.labelLarge.copyWith(
                      color: ZadColors.green700,
                    ),
                  ),
                ),
                const SizedBox(width: ZadSpacing.sm),
              ],
              Flexible(child: bubble),
            ],
          ),
          if (reactions.isNotEmpty)
            Padding(
              padding: EdgeInsetsDirectional.only(start: isMe ? 0 : 40),
              child: Wrap(
                spacing: ZadSpacing.xs,
                children: <Widget>[
                  for (final (emoji, count) in reactions)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => unawaited(
                        ref
                            .read(familyLifeControllerProvider.notifier)
                            .react(message, emoji),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ZadColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('$emoji $count', style: ZadType.labelSmall),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TextBubble extends ConsumerWidget {
  const new({
    required this.message,
    required this.alias,
    required this.isMe,
    required this.isAi,
    required this.pickerOpen,
    required this.onTogglePicker,
  });

  final FamilyMessage message;
  final String alias;
  final bool isMe;
  final bool isAi;
  final bool pickerOpen;
  final VoidCallback onTogglePicker;

  static const List<String> _emojis = <String>[
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
    '🙏',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(familyLifeControllerProvider.notifier);
    final fg = isMe ? Colors.white : ZadColors.ink;
    final muted = isMe
        ? Colors.white.withValues(alpha: 0.7)
        : ZadColors.inkMuted;
    return FractionallySizedBox(
      widthFactor: 0.8,
      alignment: isMe
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(ZadSpacing.md),
            decoration: BoxDecoration(
              color: isMe
                  ? ZadColors.green700
                  : isAi
                  ? ZadColors.mint100.withValues(alpha: 0.8)
                  : ZadColors.surfaceVariant,
              borderRadius: BorderRadiusDirectional.only(
                topStart: const Radius.circular(16),
                topEnd: const Radius.circular(16),
                bottomStart: Radius.circular(isMe ? 16 : 4),
                bottomEnd: Radius.circular(isMe ? 4 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (!isMe)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (isAi) ...<Widget>[
                        const Icon(
                          ZadIcons.assistant,
                          size: 11,
                          color: ZadColors.green700,
                        ),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        alias,
                        style: ZadType.labelSmall.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isAi ? ZadColors.green700 : ZadColors.inkMuted,
                        ),
                      ),
                      if (message.isPinned) ...<Widget>[
                        const SizedBox(width: ZadSpacing.xs),
                        Icon(ZadIcons.pin, size: 12, color: muted),
                      ],
                    ],
                  )
                else if (message.isPinned)
                  Icon(ZadIcons.pin, size: 12, color: muted),
                if (message.voiceUrl != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(ZadIcons.play, size: 20, color: fg),
                      const SizedBox(width: ZadSpacing.sm),
                      Text(
                        'رسالة صوتية',
                        style: ZadType.bodySmall.copyWith(color: fg),
                      ),
                    ],
                  )
                else
                  Text(
                    message.message,
                    style: ZadType.bodyMedium.copyWith(color: fg),
                  ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      _time(message.createdAt),
                      style: ZadType.labelSmall.copyWith(
                        fontSize: 9,
                        color: muted,
                      ),
                    ),
                    if (isMe) ...<Widget>[
                      const SizedBox(width: 3),
                      Icon(ZadIcons.markAllRead, size: 12, color: muted),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                tooltip: message.isPinned ? 'إلغاء التثبيت' : 'تثبيت',
                visualDensity: VisualDensity.compact,
                onPressed: () => unawaited(controller.togglePin(message)),
                icon: Icon(
                  ZadIcons.pin,
                  size: 14,
                  color: message.isPinned
                      ? ZadColors.green700
                      : ZadColors.inkMuted.withValues(alpha: 0.5),
                ),
              ),
              IconButton(
                tooltip: 'تفاعل',
                visualDensity: VisualDensity.compact,
                onPressed: onTogglePicker,
                icon: Icon(
                  ZadIcons.react,
                  size: 14,
                  color: ZadColors.inkMuted.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          if (pickerOpen)
            Wrap(
              spacing: ZadSpacing.xs,
              children: <Widget>[
                for (final e in _emojis)
                  InkResponse(
                    radius: 18,
                    onTap: () {
                      unawaited(controller.react(message, e));
                      onTogglePicker();
                    },
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: ZadColors.surface,
                      child: Text(e, style: const TextStyle(fontSize: 14)),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SosBubble extends StatelessWidget {
  const new({required this.message, required this.alias});

  final FamilyMessage message;
  final String alias;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    widthFactor: 0.9,
    alignment: AlignmentDirectional.centerStart,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZadColors.terracottaRust.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ZadColors.terracottaRust.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 20,
            backgroundColor: ZadColors.terracottaRust,
            child: const Icon(ZadIcons.sos, color: Colors.white, size: 20),
          ),
          const SizedBox(width: ZadSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'نداء طوارئ من $alias!',
                  style: ZadType.titleSmall.copyWith(
                    color: ZadColors.terracottaRust,
                  ),
                ),
                const SizedBox(height: 2),
                Text(message.message, style: ZadType.bodyMedium),
                const SizedBox(height: ZadSpacing.xs),
                Text(
                  _time(message.createdAt),
                  style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _RequestBubble extends ConsumerWidget {
  const new({
    required this.message,
    required this.alias,
    required this.canDecide,
  });

  final FamilyMessage message;
  final String alias;
  final bool canDecide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = message.requestStatus;
    final controller = ref.read(familyLifeControllerProvider.notifier);
    return FractionallySizedBox(
      widthFactor: 0.9,
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.all(ZadSpacing.lg),
        decoration: BoxDecoration(
          color: ZadColors.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ZadColors.green700),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(ZadIcons.shopping, color: ZadColors.green700),
                const SizedBox(width: ZadSpacing.sm),
                Expanded(
                  child: Text(
                    'طلب شراء من $alias',
                    style: ZadType.titleSmall.copyWith(
                      color: ZadColors.green700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZadSpacing.sm),
            Text(message.message, style: ZadType.bodyMedium),
            if (status == RequestStatus.pending && canDecide) ...<Widget>[
              const SizedBox(height: ZadSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  FilledButton(
                    onPressed: () {
                      unawaited(HapticFeedback.heavyImpact());
                      unawaited(controller.decide(message, approve: true));
                    },
                    child: const Text('موافقة وخصم'),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ZadColors.terracottaRust,
                    ),
                    onPressed: () {
                      unawaited(HapticFeedback.selectionClick());
                      unawaited(controller.decide(message, approve: false));
                    },
                    child: const Text('رفض'),
                  ),
                ],
              ),
            ] else if (status == RequestStatus.approved) ...<Widget>[
              const SizedBox(height: ZadSpacing.sm),
              const _Status(
                icon: ZadIcons.selected,
                text: 'تمت الموافقة',
                color: ZadColors.green700,
              ),
            ] else if (status == RequestStatus.rejected) ...<Widget>[
              const SizedBox(height: ZadSpacing.sm),
              _Status(
                icon: ZadIcons.rejected,
                text: 'مرفوض',
                color: ZadColors.terracottaRust,
              ),
            ],
            const SizedBox(height: 6),
            Text(
              _time(message.createdAt),
              style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const new({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Icon(icon, size: 16, color: color),
      const SizedBox(width: ZadSpacing.xs),
      Text(text, style: ZadType.labelMedium.copyWith(color: color)),
    ],
  );
}

class _PollBubble extends ConsumerWidget {
  const new({required this.message, required this.alias, required this.myId});

  final FamilyMessage message;
  final String alias;
  final String myId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = message.pollOptions;
    final votes = message.pollVotes;
    final total = votes.length;
    final mine = votes[myId];
    return FractionallySizedBox(
      widthFactor: 0.9,
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.all(ZadSpacing.lg),
        decoration: BoxDecoration(
          color: ZadColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ZadColors.mustardOchre),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(ZadIcons.poll, color: ZadColors.mustardOchre),
                const SizedBox(width: ZadSpacing.sm),
                Text(
                  'تصويت من $alias',
                  style: ZadType.titleSmall.copyWith(
                    color: ZadColors.mustardOchre,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZadSpacing.sm),
            Text(message.pollQuestion, style: ZadType.titleSmall),
            const SizedBox(height: ZadSpacing.sm),
            for (final (i, option) in options.indexed) ...<Widget>[
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => unawaited(
                  ref
                      .read(familyLifeControllerProvider.notifier)
                      .vote(message, i),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZadSpacing.md,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: mine == i
                        ? ZadColors.mustardOchre.withValues(alpha: 0.15)
                        : ZadColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: mine == i
                        ? Border.all(color: ZadColors.mustardOchre, width: 1.5)
                        : null,
                  ),
                  child: Row(
                    children: <Widget>[
                      if (mine == i) ...<Widget>[
                        Icon(
                          ZadIcons.selected,
                          size: 16,
                          color: ZadColors.mustardOchre,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          '${i + 1}. $option',
                          style: ZadType.bodyMedium,
                        ),
                      ),
                      if (total > 0)
                        Text(
                          _share(
                            votes.values.where((v) => v == i).length,
                            total,
                          ),
                          style: ZadType.labelSmall.copyWith(
                            color: mine == i
                                ? ZadColors.mustardOchre
                                : ZadColors.inkMuted,
                            fontWeight: mine == i
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: ZadSpacing.xs),
            ],
            Text(
              _time(message.createdAt),
              style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const new({
    required this.text,
    required this.quickReplies,
    required this.onToggleQuickReplies,
    required this.onQuickReply,
    required this.onSend,
    required this.onSos,
    required this.onRequest,
    required this.onPoll,
    required this.onTask,
    required this.onGrocery,
  });

  final TextEditingController text;
  final bool quickReplies;
  final VoidCallback onToggleQuickReplies;
  final ValueChanged<String> onQuickReply;
  final VoidCallback onSend;
  final VoidCallback onSos;
  final VoidCallback onRequest;
  final VoidCallback onPoll;
  final VoidCallback onTask;
  final VoidCallback onGrocery;

  @override
  Widget build(BuildContext context) => Material(
    color: ZadColors.surface.withValues(alpha: 0.95),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ZadSpacing.md,
          vertical: ZadSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (quickReplies)
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: <Widget>[
                    for (final (emoji, reply) in kFamilyQuickReplies)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: ActionChip(
                          label: Text('$emoji $reply'),
                          backgroundColor: ZadColors.mint100.withValues(
                            alpha: 0.6,
                          ),
                          shape: const StadiumBorder(),
                          onPressed: () => onQuickReply(reply),
                        ),
                      ),
                  ],
                ),
              ),
            Row(
              children: <Widget>[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          tooltip: 'ردود سريعة',
                          onPressed: onToggleQuickReplies,
                          icon: const Icon(
                            ZadIcons.add,
                            color: ZadColors.green700,
                          ),
                        ),
                        IconButton(
                          tooltip: 'نداء طوارئ',
                          onPressed: onSos,
                          icon: Icon(
                            ZadIcons.sos,
                            color: ZadColors.terracottaRust,
                          ),
                        ),
                        IconButton(
                          tooltip: 'طلب مصروف',
                          onPressed: onRequest,
                          icon: const Icon(
                            ZadIcons.shopping,
                            color: ZadColors.green700,
                          ),
                        ),
                        IconButton(
                          tooltip: 'تصويت',
                          onPressed: onPoll,
                          icon: Icon(
                            ZadIcons.poll,
                            color: ZadColors.mustardOchre,
                          ),
                        ),
                        IconButton(
                          tooltip: 'المهام',
                          onPressed: onTask,
                          icon: const Icon(
                            ZadIcons.chore,
                            color: ZadColors.green700,
                          ),
                        ),
                        IconButton(
                          tooltip: 'البقالة',
                          onPressed: onGrocery,
                          icon: Icon(
                            ZadIcons.inventory,
                            color: ZadColors.mustardOchre,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsetsDirectional.only(
                      start: ZadSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: ZadColors.surfaceLow,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: ZadColors.outline),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: text,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => onSend(),
                            decoration: const InputDecoration(
                              hintText: 'اكتب رسالة أو @Zad...',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'إرسال',
                          onPressed: onSend,
                          icon: const CircleAvatar(
                            radius: 18,
                            backgroundColor: ZadColors.green700,
                            child: Icon(
                              ZadIcons.send,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
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
