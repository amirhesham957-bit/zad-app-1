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
import 'package:zad/core/data/providers.dart';
import 'package:zad/core/design/foundation/squircle.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_icons.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/shared/ads/presentation/watch_ad_button.dart';
import 'package:zad/shared/chat/application/chat_controller.dart';
import 'package:zad/shared/chat/application/voice_input_controller.dart';
import 'package:zad/shared/chat/domain/agent_turn.dart';
import 'package:zad/shared/chat/domain/chat_message.dart';
import 'package:zad/shared/household/domain/home_emergency.dart';
import 'package:zad/shared/navigation/zad_screens.dart';
import 'package:zad/shared/quota/application/attempts_balance_provider.dart';
import 'package:zad/shared/quota/presentation/attempts_chip.dart';
import 'package:zad/shared/voice/application/voice_output_controller.dart';

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

  /// The composer holds words the customer spoke. Cleared when the field is
  /// emptied by hand, so typing afresh is a typed message again.
  bool _spoken = false;

  /// A home emergency the last message described (الشريحة ٤٣): the card over
  /// the composer opens the trusted technicians with that trade first.
  TechnicianTrade? _emergency;

  @override
  void initState() {
    super.initState();
    // A question offered before this screen was open (the home's urgent
    // recipes card pushes it right after offering).
    final pending = ref.read(chatPrefillProvider);
    if (pending != null) {
      _composer.text = pending;
      unawaited(
        Future<void>.microtask(() {
          if (mounted) ref.read(chatPrefillProvider.notifier).taken();
        }),
      );
    }
  }

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
    final spoken = _spoken;
    _composer.clear();
    final emergency = homeEmergencyTrade(text);
    setState(() {
      _spoken = false;
      if (emergency != null) _emergency = emergency;
    });
    await ref
        .read(chatControllerProvider.notifier)
        .send(text, viaVoice: spoken);
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(chatControllerProvider);

    // The words land in the field, not in a turn. Whisper on dialect Arabic is
    // good and not certain, and "خمسين" against "خمسمية" is money — so they
    // are read before they are sent. Appended rather than assigned: somebody
    // who typed half a sentence and then spoke the rest means both.
    ref.listen(voiceInputControllerProvider, (previous, next) {
      final transcript = next.transcript;
      if (transcript == null) return;
      final existing = _composer.text.trim();
      _composer.text = existing.isEmpty ? transcript : '$existing $transcript';
      _composer.selection = TextSelection.collapsed(
        offset: _composer.text.length,
      );
      ref.read(voiceInputControllerProvider.notifier).transcriptTaken();
      setState(() => _spoken = true);
    });

    // A question another screen offered (the map's "اسأل زاد"). It lands in
    // the field like a transcript does, and waits for the customer to send it.
    ref.listen(chatPrefillProvider, (previous, next) {
      if (next == null) return;
      _composer
        ..text = next
        ..selection = TextSelection.collapsed(offset: next.length);
      ref.read(chatPrefillProvider.notifier).taken();
      setState(() {});
    });

    // Kotlin's voice_unavailable toast: silence says nothing on its own.
    ref.listen(voiceOutputControllerProvider.select((v) => v.failed), (_, f) {
      if (!f) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.chatVoiceUnavailable)),
      );
    });

    // The agent's app_command is opened by ZadShell, for every surface.

    // «طاقة زاد»: a reply may have spent attempts, so the chip re-reads the
    // server's balance once the reply is in — never a local guess.
    ref.listen(chatControllerProvider.select((v) => v.isAwaitingReply), (
      was,
      now,
    ) {
      if (was == true && !now) ref.invalidate(attemptsBalanceProvider);
    });

    return DecoratedBox(
      decoration: BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(context.l10n.appTitle),
          actions: <Widget>[
            const AttemptsChip(),
            IconButton(
              onPressed: () => ZadScreens.showBrainHub(context),
              icon: const Icon(ZadIcons.brain),
              tooltip: context.l10n.drawerBrain,
            ),
            if (!view.isEmpty)
              IconButton(
                onPressed: () => _confirmClear(context),
                icon: const Icon(ZadIcons.dismiss),
                tooltip: context.l10n.chatNewTooltip,
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
            if (_emergency case final trade?)
              EmergencyTechniciansCard(
                trade: trade,
                onOpen: () => unawaited(
                  ZadScreens.showTrustedTechnicians(context, trade: trade.wire),
                ),
                onDismiss: () => setState(() => _emergency = null),
              ),
            _Composer(
              controller: _composer,
              busy: view.isAwaitingReply,
              onChanged: () => setState(() {
                if (_composer.text.trim().isEmpty) _spoken = false;
              }),
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
        title: Text(context.l10n.chatNewTitle),
        content: Text(
          // Said plainly, because it is not obvious: what زاد knows about the
          // customer lives on the server and survives this. Only the
          // scrollback on this phone goes.
          context.l10n.chatNewBody,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.commonWait),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.chatClear),
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
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(ZadSpacing.gutter),
    children: <Widget>[_Bubble(message: zadWelcomeMessage(context.l10n))],
  );
}

/// Kotlin's opening message (`zad_welcome_message`): shown while the
/// conversation is empty, never saved and never sent.
ChatMessage zadWelcomeMessage(ZadL10n l10n) => ChatMessage(
  id: 'init',
  text: l10n.chatWelcome,
  isUser: false,
  createdAt: DateTime.utc(2000),
);

/// Kotlin's reply when a turn fails: `zad_ai_busy` when the providers were
/// out of capacity, `zad_unexpected_error` otherwise.
String chatFailureReply(Object? error, [ZadL10n? l10n]) {
  final l = l10n ?? zadL10nArabic;
  final e = '$error';
  return e.contains('429') ||
          e.contains('503') ||
          e.contains('ProviderUnavailable')
      ? l.chatBusy
      : l.chatUnexpected;
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

          if (!mine &&
              message.status == ChatStatus.done &&
              message.text.trim().isNotEmpty)
            _SpeakButton(message: message),

          if (message.specialist case final specialist?) ...<Widget>[
            const SizedBox(height: ZadSpacing.xs),
            Text(
              specialist,
              style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
            ),
          ],

          // Receipts for what the server already did, not buttons. The write
          // has happened; this is the record of it.
          for (final receipt in message.executed) ChatReceipt(receipt: receipt),

          // And the opposite: nothing has happened yet.
          for (final proposal in message.proposals)
            ChatProposal(messageId: message.id, proposal: proposal),

          if (message.lock case final lock?) ChatLockCard(lock: lock),

          if (failed && mine) ...<Widget>[
            const SizedBox(height: ZadSpacing.xs),
            _Bubble(
              message: ChatMessage(
                id: '${message.id}:failure',
                text: chatFailureReply(
                  ref.watch(chatControllerProvider.select((v) => v.error)),
                ),
                isUser: false,
                createdAt: message.createdAt,
              ),
            ),
            TextButton.icon(
              onPressed: () =>
                  ref.read(chatControllerProvider.notifier).retry(message.id),
              icon: const Icon(ZadIcons.retry, size: 16),
              label: Text(context.l10n.chatResend),
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

/// Reads a reply aloud — Kotlin's speak icon on each of Zad's bubbles. The
/// same button stops it while it is this message that is playing.
class _SpeakButton extends ConsumerWidget {
  const new({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voice = ref.watch(voiceOutputControllerProvider);
    final mine = voice.isActive && voice.messageId == message.id;
    final controller = ref.read(voiceOutputControllerProvider.notifier);
    return IconButton(
      tooltip: mine ? context.l10n.chatStopVoice : context.l10n.chatListen,
      onPressed: () => unawaited(
        mine
            ? controller.stop()
            : controller.speak(message.text, messageId: message.id),
      ),
      icon: mine && voice.stage == VoiceOutputStage.preparing
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              mine ? ZadIcons.silence : ZadIcons.listen,
              size: 20,
              color: ZadColors.inkMuted,
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
        context.l10n.chatThinking,
        style: ZadType.bodySmall.copyWith(color: ZadColors.inkMuted),
      ),
    ],
  );
}

/// Something the server did.
class ChatReceipt extends StatelessWidget {
  /// Creates the receipt.
  const new({required this.receipt, super.key});

  /// What was done.
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

/// When the attempts come back, said as a span of time — never a clock time,
/// which would need the account's zone to be right.
String refillPhrase(DateTime refillAt, DateTime now, [ZadL10n? l10n]) {
  final l = l10n ?? zadL10nArabic;
  final minutes = (refillAt.difference(now).inSeconds / 60).ceil();
  if (minutes <= 0) return l.refillBack;
  if (minutes >= 48 * 60) {
    return l.refillDays((minutes / 1440).ceil());
  }
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final hours = switch (h) {
    0 => '',
    1 => l.refillHour,
    2 => l.refillTwoHours,
    <= 10 => l.refillFewHours(h),
    _ => l.refillManyHours(h),
  };
  final mins = m == 0 ? '' : l.refillMinutes(m);
  final span = [hours, mins].where((p) => p.isNotEmpty).join(l.refillAnd);
  return l.refillIn(span);
}

/// The way out under a reply that says the attempts ran out (ZAD_PLAN ٢.٨):
/// an ad that buys them back, when they return on their own, and the plans —
/// in that order, the cheapest for the customer first. The written reply
/// already said «تقدر تشوف إعلان»; this is the button it promised.
class ChatLockCard extends ConsumerWidget {
  /// Creates the card.
  const new({required this.lock, super.key});

  /// Why the turn was refused.
  final AgentLock lock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider)();
    final refill = lock.refillAt;
    // Once the attempts are back the card has nothing left to offer.
    if (refill != null && !refill.isAfter(now) && lock.adCanHelp) {
      return const SizedBox.shrink();
    }
    return Padding(
      key: const ValueKey<String>('chat-lock'),
      padding: const EdgeInsets.only(top: ZadSpacing.sm),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: ZadColors.mustardOchre.withValues(alpha: 0.10),
          shape: zadSquircle(ZadRadii.card),
        ),
        child: Padding(
          padding: const EdgeInsets.all(ZadSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (lock.adCanHelp) const WatchAdButton(),
              if (refill != null) ...<Widget>[
                const SizedBox(height: ZadSpacing.sm),
                Text(
                  refillPhrase(refill, now, context.l10n),
                  textAlign: TextAlign.center,
                  style: ZadType.labelMedium.copyWith(color: ZadColors.slate),
                ),
              ],
              const SizedBox(height: ZadSpacing.sm),
              FilledButton(
                key: const ValueKey<String>('chat-lock-subscribe'),
                onPressed: () => ZadScreens.showPaywallScreen(context),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                child: Text(
                  lock.reason == 'premium_only'
                      ? context.l10n.chatSubscribeFeature
                      : context.l10n.chatSubscribeMore,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Something the server is waiting to be allowed to do.
class ChatProposal extends ConsumerWidget {
  /// Creates the card.
  const new({required this.messageId, required this.proposal, super.key});

  /// The reply it came with.
  final String messageId;

  /// What would be done.
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
                context.l10n.chatNotDone,
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
                      child: Text(context.l10n.chatDoIt),
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

class _Composer extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final voice = ref.watch(voiceInputControllerProvider);
    final canSend = !busy && controller.text.trim().isNotEmpty;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(ZadSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_hint(voice.stage, context.l10n) case final hint?) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: ZadSpacing.sm),
                child: Text(
                  hint,
                  style: ZadType.labelSmall.copyWith(
                    color: voice.stage == VoiceStage.denied
                        ? ZadColors.terracottaRust
                        : ZadColors.inkMuted,
                  ),
                ),
              ),
            ],
            if (voice.isRecording)
              _Recording(amplitude: voice.amplitude)
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 5,
                      enabled: voice.stage != VoiceStage.transcribing,
                      textInputAction: TextInputAction.send,
                      onChanged: (_) => onChanged(),
                      onSubmitted: (_) => canSend ? onSend() : null,
                      decoration: InputDecoration(
                        hintText: voice.stage == VoiceStage.transcribing
                            ? context.l10n.chatTranscribing
                            : context.l10n.chatHint,
                        filled: true,
                        fillColor: ZadColors.surface,
                      ),
                    ),
                  ),
                  const SizedBox(width: ZadSpacing.sm),
                  _MicButton(stage: voice.stage),
                  const SizedBox(width: ZadSpacing.sm),
                  SizedBox(
                    width: kZadMinTapTarget,
                    height: kZadMinTapTarget,
                    child: IconButton.filled(
                      onPressed: canSend ? onSend : null,
                      icon: const Icon(ZadIcons.forward, size: 20),
                      tooltip: context.l10n.chatSend,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// What to say about the microphone, or nothing at all.
  static String? _hint(VoiceStage stage, ZadL10n l10n) => switch (stage) {
    // Named as the nudge it is, not as an error. The fix is to hold it a
    // moment longer, and saying so is what breaks the habit of tapping again.
    VoiceStage.tooShort => l10n.voiceTooShort,
    VoiceStage.denied => l10n.voiceDenied,
    VoiceStage.failed => l10n.voiceFailed,
    _ => null,
  };
}

/// The microphone button, in whichever state it is in.
class _MicButton extends ConsumerWidget {
  const new({required this.stage});

  final VoiceStage stage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(voiceInputControllerProvider.notifier);
    final transcribing = stage == VoiceStage.transcribing;

    return SizedBox(
      width: kZadMinTapTarget,
      height: kZadMinTapTarget,
      child: transcribing
          ? const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : IconButton(
              onPressed: () => unawaited(controller.start()),
              icon: const Icon(ZadIcons.voice, size: 20),
              tooltip: context.l10n.voiceRecord,
              style: IconButton.styleFrom(
                foregroundColor: ZadColors.green800,
                backgroundColor: ZadColors.mint50,
              ),
            ),
    );
  }
}

/// What the composer becomes while the microphone is live.
///
/// It replaces the field rather than sitting beside it, because the one thing
/// a customer needs to know here is that it **is** recording — the habit this
/// is fixing is pressing again because nothing looked different.
class _Recording extends ConsumerWidget {
  const new({required this.amplitude});

  final double amplitude;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(voiceInputControllerProvider.notifier);

    return Row(
      children: <Widget>[
        SizedBox(
          width: kZadMinTapTarget,
          height: kZadMinTapTarget,
          child: IconButton(
            onPressed: () => unawaited(controller.cancel()),
            icon: const Icon(ZadIcons.dismiss, size: 20),
            tooltip: context.l10n.commonCancel,
            style: IconButton.styleFrom(foregroundColor: ZadColors.inkMuted),
          ),
        ),
        const SizedBox(width: ZadSpacing.sm),
        Expanded(
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: ZadColors.surface,
              shape: zadSquircle(ZadRadii.pill),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZadSpacing.lg,
                vertical: ZadSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  const _RecordingDot(),
                  const SizedBox(width: ZadSpacing.md),
                  Expanded(child: _Waveform(amplitude: amplitude)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: ZadSpacing.sm),
        SizedBox(
          width: kZadMinTapTarget,
          height: kZadMinTapTarget,
          child: IconButton.filled(
            onPressed: () => unawaited(controller.stopAndTranscribe()),
            icon: const Icon(ZadIcons.synced, size: 20),
            tooltip: context.l10n.voiceDone,
          ),
        ),
      ],
    );
  }
}

/// The red dot, breathing.
class _RecordingDot extends StatefulWidget {
  const new();

  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: 0.35, end: 1).animate(_pulse),
    child: Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: ZadColors.terracottaRust,
        shape: BoxShape.circle,
      ),
    ),
  );
}

/// A row of bars that answers the voice.
///
/// Driven by the recorder's own amplitude stream, so it moves when the
/// microphone hears something and stays flat when it does not — which is the
/// feedback that says the session is genuinely open, rather than an animation
/// that would look identical over a dead capture.
class _Waveform extends StatelessWidget {
  const new({required this.amplitude});

  final double amplitude;

  static const int _bars = 18;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 24,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        for (var i = 0; i < _bars; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 3,
            height: _heightFor(i),
            decoration: BoxDecoration(
              color: ZadColors.green600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    ),
  );

  /// Bars nearer the middle react more, so the row reads as a voice rather
  /// than as a level meter.
  double _heightFor(int index) {
    const centre = (_bars - 1) / 2;
    final distance = (index - centre).abs() / centre;
    final weight = 1 - (distance * 0.7);
    return 4 + (amplitude * 20 * weight);
  }
}

/// «طوارئ في البيت؟» over the composer: one tap to the technicians the
/// customer trusts, the matching trade first. For gas, the safety line comes
/// before anything else.
class EmergencyTechniciansCard extends StatelessWidget {
  /// Creates the card.
  const new({
    required this.trade,
    required this.onOpen,
    required this.onDismiss,
    super.key,
  });

  /// The trade the message called for.
  final TechnicianTrade trade;

  /// Opens the list.
  final VoidCallback onOpen;

  /// Hides the card.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      ZadSpacing.gutter,
      0,
      ZadSpacing.gutter,
      ZadSpacing.sm,
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: ZadColors.surface,
        borderRadius: BorderRadius.circular(ZadRadii.card),
        border: Border.all(color: ZadColors.terracottaRust),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ZadSpacing.md),
        child: Row(
          children: <Widget>[
            Icon(Icons.handyman_outlined, color: ZadColors.terracottaRust),
            const SizedBox(width: ZadSpacing.sm),
            Expanded(
              child: Text(
                trade == TechnicianTrade.gas
                    ? kGasSafetyLine
                    : context.l10n.chatEmergency(trade.label),
                style: ZadType.bodySmall.copyWith(color: ZadColors.ink),
              ),
            ),
            TextButton(
              onPressed: onOpen,
              child: Text(context.l10n.chatTechnicians),
            ),
            IconButton(
              tooltip: context.l10n.commonHide,
              onPressed: onDismiss,
              icon: const Icon(ZadIcons.dismiss, size: 18),
            ),
          ],
        ),
      ),
    ),
  );
}
