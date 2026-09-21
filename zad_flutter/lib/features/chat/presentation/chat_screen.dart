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
import 'package:zad/features/brain/presentation/brain_hub_screen.dart';
import 'package:zad/features/chat/application/chat_controller.dart';
import 'package:zad/features/chat/application/voice_input_controller.dart';
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
      setState(() {});
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

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: ZadColors.canvas),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('زاد'),
          actions: <Widget>[
            IconButton(
              onPressed: () => showBrainHub(context),
              icon: const Icon(ZadIcons.brain),
              tooltip: 'عقل زاد',
            ),
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
            if (_hint(voice.stage) case final hint?) ...<Widget>[
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
                            ? 'بحوّل الكلام…'
                            : 'اكتب لزاد…',
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
                      tooltip: 'ابعت',
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
  static String? _hint(VoiceStage stage) => switch (stage) {
    // Named as the nudge it is, not as an error. The fix is to hold it a
    // moment longer, and saying so is what breaks the habit of tapping again.
    VoiceStage.tooShort => 'مسكت الزرار بسرعة — دوس وابدأ اتكلم، وبعدين قف.',
    VoiceStage.denied =>
      'محتاج إذن المايك. افتح إعدادات التطبيق واسمح بالتسجيل.',
    VoiceStage.failed => 'مقدرتش أحوّل الكلام. جرب تاني.',
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
              tooltip: 'سجّل صوت',
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
            tooltip: 'إلغاء',
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
            tooltip: 'خلصت',
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
      decoration: const BoxDecoration(
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
