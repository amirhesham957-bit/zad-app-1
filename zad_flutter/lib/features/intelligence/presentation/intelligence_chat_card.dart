/// Kotlin's `ChatSectionCard` and `ChatTab` (`ZadIntelligenceScreen.kt`): the
/// conversation with عقل زاد inside the brain screen — a card that opens to
/// 560dp with the orb, «مسح المحادثة», the six quick prompts, the bubbles
/// with «استمع» and the memory hint, the typing dots, `NeuralMeshBadge`, the
/// auto-voice toggle and the composer.
///
/// The same conversation as the chat tab (`chatControllerProvider`), so a
/// turn started here is there too. Kotlin re-opens the microphone after a
/// spoken reply; here the microphone is a tap to start and a tap to send,
/// and it never opens on its own.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/components/zad_kotlin_surfaces.dart';
import 'package:zad/design/tokens/zad_extended_colors.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/chat/application/chat_controller.dart';
import 'package:zad/features/chat/application/voice_input_controller.dart';
import 'package:zad/features/chat/domain/chat_message.dart';
import 'package:zad/features/chat/presentation/chat_screen.dart';
import 'package:zad/features/orb/application/companion_mood.dart';
import 'package:zad/features/orb/domain/companion_state.dart';
import 'package:zad/features/orb/presentation/companion_orb.dart';
import 'package:zad/features/voice/zad_voice.dart';

// Kotlin's `zad_voice` preference, `auto_tts`, on by default.
const String _autoTtsKey = 'zad_voice:auto_tts';

bool _autoTts(Box<String> box) => box.get(_autoTtsKey) != 'false';

/// Kotlin's `ChatSectionCard`.
class ChatSectionCard extends ConsumerWidget {
  /// Creates the card.
  const new({required this.expanded, required this.onToggle, super.key});

  /// Open or not.
  final bool expanded;

  /// Opens or folds it.
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final mood = ref.watch(companionMoodProvider);
    return ZadListCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: <Widget>[
                  CompanionOrb(state: mood, size: 40, animated: false),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'محادثة مع زاد',
                          style: ZadType.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          'اسأل عن مصاريفك، مخزونك، أو أي حاجة',
                          style: ZadType.bodySmall.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: scheme.onSurfaceVariant,
                    semanticLabel: expanded
                        ? 'إخفاء المحادثة'
                        : 'افتح المحادثة',
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: expanded
                ? const SizedBox(height: 560, child: ChatTab())
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Kotlin's `ChatTab`.
class ChatTab extends ConsumerStatefulWidget {
  /// Creates the tab.
  const new({super.key});

  @override
  ConsumerState<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends ConsumerState<ChatTab> {
  static const List<(IconData, String)> _prompts = <(IconData, String)>[
    (Icons.restaurant, 'اقترح وصفة من الثلاجة'),
    (Icons.bar_chart, 'حلل مصاريفي هذا الشهر'),
    (Icons.shopping_cart, 'ما الذي ينقصني للتسوق؟'),
    (Icons.monetization_on, 'كيف أوفر أكثر هذا الشهر؟'),
    (Icons.assignment, 'اكتشف اشتراكاتي'),
    (Icons.eco, 'وجبة صحية سريعة'),
  ];

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  late final Box<String> _box = ref.read(localStoreProvider).device;
  late bool _autoTtsOn = _autoTts(_box);
  bool _awaitingVoiceReply = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String text, {bool voice = false}) {
    final clean = text.trim();
    if (clean.isEmpty) return;
    if (voice || _autoTtsOn) _awaitingVoiceReply = true;
    _input.clear();
    unawaited(ref.read(chatControllerProvider.notifier).send(clean));
  }

  Future<void> _mic() async {
    final voice = ref.read(voiceInputControllerProvider.notifier);
    if (ref.read(voiceInputControllerProvider).isRecording) {
      await voice.stopAndTranscribe();
    } else {
      ref.read(zadVoiceProvider).stop();
      await voice.start();
    }
  }

  Future<void> _confirmClear() async {
    final scheme = Theme.of(context).colorScheme;
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text(
          'مسح المحادثة',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'هنمسح كل رسائل المحادثة مع عقل زاد. البيانات المالية والمخزون مش '
          'هتتأثر.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text('مسح المحادثة', style: TextStyle(color: scheme.error)),
          ),
        ],
      ),
    );
    if (sure ?? false) await ref.read(chatControllerProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = context.zadExt;
    final chat = ref.watch(chatControllerProvider);
    final messages = chat.messages;
    final mood = ref.watch(companionMoodProvider);
    final listening = ref.watch(
      voiceInputControllerProvider.select((v) => v.isRecording),
    );
    final lastSpecialist = messages
        .where((m) => !m.isUser)
        .map((m) => m.specialist)
        .lastOrNull;

    ref
      ..listen(voiceInputControllerProvider, (_, next) {
        final heard = next.transcript;
        if (heard != null) {
          ref.read(voiceInputControllerProvider.notifier).transcriptTaken();
          _send(heard, voice: true);
        }
      })
      ..listen(chatControllerProvider.select((v) => v.messages.length), (_, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.animateTo(
              _scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      })
      ..listen(chatControllerProvider.select((v) => v.isAwaitingReply), (
        was,
        now,
      ) {
        if (was != true || now || !_awaitingVoiceReply) return;
        _awaitingVoiceReply = false;
        final reply = ref
            .read(chatControllerProvider)
            .messages
            .where((m) => !m.isUser)
            .lastOrNull;
        if (reply != null && reply.text.trim().isNotEmpty) {
          unawaited(ref.read(zadVoiceProvider).speak(reply.text));
        }
      });

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CompanionOrb(state: mood, size: 64),
        ),
        if (messages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: () => unawaited(_confirmClear()),
                icon: Icon(
                  Icons.delete_sweep,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                label: Text(
                  'مسح المحادثة',
                  style: ZadType.labelSmall.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              if (messages.isEmpty) ...<Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      'اسأل زاد عن أي شيء',
                      style: ZadType.labelMedium.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_downward,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < _prompts.length; i += 2) ...<Widget>[
                  Row(
                    children: <Widget>[
                      for (final (icon, prompt) in _prompts.skip(i).take(2))
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: Material(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => _send(prompt),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    children: <Widget>[
                                      Icon(
                                        icon,
                                        size: 20,
                                        color: scheme.primary,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        prompt,
                                        textAlign: TextAlign.center,
                                        style: ZadType.labelSmall.copyWith(
                                          color: scheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              // Kotlin's opening message, while there is nothing else.
              if (messages.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _IntChatBubble(message: kZadWelcomeMessage),
                ),
              for (final m in messages)
                if (!(m.isStreaming && m.text.isEmpty))
                  Padding(
                    key: ValueKey<String>(m.id),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _IntChatBubble(message: m),
                  ),
              if (chat.isAwaitingReply) ...<Widget>[
                const _TypingIndicator(),
                Center(
                  child: NeuralMeshBadge(
                    status: NeuralMeshStatus.thinking,
                    specialistId: lastSpecialist,
                  ),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Center(
                    child: NeuralMeshBadge(
                      status: lastSpecialist != null
                          ? NeuralMeshStatus.active
                          : NeuralMeshStatus.idle,
                      specialistId: lastSpecialist,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        ColoredBox(
          color: scheme.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: <Widget>[
                SizedBox.square(
                  dimension: 36,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Auto TTS',
                    onPressed: () {
                      setState(() => _autoTtsOn = !_autoTtsOn);
                      unawaited(_box.put(_autoTtsKey, '$_autoTtsOn'));
                    },
                    icon: Icon(
                      _autoTtsOn ? Icons.volume_up : Icons.volume_off,
                      color: _autoTtsOn
                          ? scheme.primary
                          : scheme.outlineVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'اسأل زاد عن ثلاجتك أو ميزانيتك...',
                      hintStyle: ZadType.bodySmall.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      filled: true,
                      fillColor: ext.surfaceContainerLow,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: scheme.outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: scheme.primary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: listening ? scheme.error : scheme.primary,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _input.text.trim().isNotEmpty
                        ? _send(_input.text)
                        : unawaited(_mic()),
                    child: SizedBox.square(
                      dimension: 46,
                      child: Icon(
                        _input.text.trim().isNotEmpty
                            ? Icons.send
                            : listening
                            ? Icons.mic
                            : Icons.mic_none,
                        color: Colors.white,
                        semanticLabel: 'إرسال',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Kotlin's `ZadIntChatBubble`.
class _IntChatBubble extends ConsumerStatefulWidget {
  const new({required this.message});

  final ChatMessage message;

  @override
  ConsumerState<_IntChatBubble> createState() => _IntChatBubbleState();
}

class _IntChatBubbleState extends ConsumerState<_IntChatBubble> {
  bool _memoryOpen = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = context.zadExt;
    final m = widget.message;
    final mine = m.isUser;
    final radius = BorderRadiusDirectional.only(
      topStart: const Radius.circular(16),
      topEnd: const Radius.circular(16),
      bottomStart: Radius.circular(mine ? 16 : 4),
      bottomEnd: Radius.circular(mine ? 4 : 16),
    );
    return Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: FractionallySizedBox(
        widthFactor: 0.75,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: mine ? scheme.primary : ext.surfaceContainerHigh,
            borderRadius: radius,
            border: mine
                ? null
                : Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!mine) ...<Widget>[
                Row(
                  children: <Widget>[
                    CompanionOrb(
                      state: companionStateForMessage(m.text),
                      size: 18,
                      animated: false,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'زاد',
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    InkResponse(
                      onTap: () =>
                          unawaited(ref.read(zadVoiceProvider).speak(m.text)),
                      radius: 12,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.volume_up,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                          semanticLabel: 'استمع',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              Text(
                m.text,
                style: ZadType.bodyMedium.copyWith(
                  color: mine ? Colors.white : scheme.onSurface,
                ),
              ),
              for (final receipt in m.executed) ChatReceipt(receipt: receipt),
              for (final proposal in m.proposals)
                ChatProposal(messageId: m.id, proposal: proposal),
              if (!mine && m.memoryAvailable.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => setState(() => _memoryOpen = !_memoryOpen),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 32),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.psychology,
                          size: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'اتبنى على ${m.memoryAvailable.length} حاجة زاد '
                            'فاكرها عنك',
                            style: ZadType.labelSmall.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_memoryOpen)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: 2,
                      start: 17,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (final hint in m.memoryAvailable)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Text(
                              '• ${hint.note}',
                              style: ZadType.labelSmall.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Kotlin's `ZadIntTypingIndicator`: three dots that rise 8dp and brighten,
/// 900ms, 150ms apart.
class _TypingIndicator extends StatefulWidget {
  const new();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: context.zadExt.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: AnimatedBuilder(
            animation: _t,
            builder: (_, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var i = 0; i < 3; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 6),
                  Builder(
                    builder: (_) {
                      // Kotlin's keyframes: up by 300ms, down by 600ms, rest.
                      final ms = (_t.value * 900 - i * 150) % 900;
                      final k = ms < 300
                          ? ms / 300
                          : ms < 600
                          ? 1 - (ms - 300) / 300
                          : 0.0;
                      return Transform.translate(
                        offset: Offset(0, -8 * k),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(
                              alpha: 0.35 + 0.65 * k,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kotlin's `NeuralMeshStatus`.
enum NeuralMeshStatus {
  /// Nothing yet.
  idle,

  /// A turn is running.
  thinking,

  /// The last reply's specialist.
  active,
}

/// Kotlin's `NeuralMeshBadge`: which of زاد's agents answered.
class NeuralMeshBadge extends StatefulWidget {
  /// Creates the badge.
  const new({required this.status, this.specialistId, super.key});

  /// The state.
  final NeuralMeshStatus status;

  /// `finance`, `pantry`, `pharmacy` or `family`.
  final String? specialistId;

  @override
  State<NeuralMeshBadge> createState() => _NeuralMeshBadgeState();
}

class _NeuralMeshBadgeState extends State<NeuralMeshBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = widget.status == NeuralMeshStatus.thinking
        ? 'الشبكة العصبية بتشتغل...'
        : switch (widget.specialistId) {
            'finance' => 'وكيل المال متصل',
            'pantry' => 'وكيل المطبخ والمخزون متصل',
            'pharmacy' => 'وكيل الصيدلية متصل',
            'family' => 'وكيل العائلة متصل',
            _ => 'شبكة وكلاء زاد',
          };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, _) => Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: switch (widget.status) {
                  NeuralMeshStatus.thinking => const Color(
                    0xFF8B5CF6,
                  ).withValues(alpha: 0.4 + 0.6 * _pulse.value),
                  NeuralMeshStatus.active => const Color(0xFF00BFA6),
                  NeuralMeshStatus.idle => scheme.onSurfaceVariant.withValues(
                    alpha: 0.35,
                  ),
                },
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            style: ZadType.labelSmall.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 10.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
