/// Kotlin's `HelpSupportScreen`: a usage-help chat (general questions only —
/// it says plainly that it cannot see the account), and the crash-log button
/// in the top bar that shows, shares or clears the on-phone log.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/tokens/zad_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_motion.dart';
import 'package:zad/design/tokens/zad_spacing.dart';
import 'package:zad/design/tokens/zad_typography.dart';

/// Opens the support screen.
Future<void> showHelpSupportScreen(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const HelpSupportScreen()),
    );

typedef _Message = ({String text, bool isUser});

const _Message _welcome = (
  text:
      'أهلاً! أنا مساعد أسئلة استخدام تطبيق زاد — أقدر أساعدك تفهم أي ميزة '
      'أو تحل مشكلة تقنية. لو سؤالك عن بياناتك الشخصية (مصاريفك، رصيدك، '
      'اشتراكاتك)، الأفضل تسأل شات "عقل زاد" لأنه هو بس اللي شايف حسابك '
      'الفعلي.',
  isUser: false,
);

/// The support chat.
class HelpSupportScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  ConsumerState<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends ConsumerState<HelpSupportScreen> {
  final List<_Message> _messages = <_Message>[_welcome];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _typing = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: ZadDuration.quick,
        curve: ZadCurves.standard,
      );
    }
  });

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _typing) return;
    _input.clear();
    setState(() {
      _messages.add((text: text, isUser: true));
      _typing = true;
    });
    _toBottom();
    final answer = await ref.read(supportAssistantProvider).ask(text);
    if (!mounted) return;
    setState(() {
      _messages.add((text: answer, isUser: false));
      _typing = false;
    });
    _toBottom();
  }

  Future<void> _crashLog() async {
    final log = ref.read(crashLogProvider);
    var text = log.exportAll();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          title: const Text('سجل الأعطال'),
          content: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              text.length > 1200 ? text.substring(0, 1200) : text,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => unawaited(
                SharePlus.instance.share(
                  ShareParams(text: text, subject: 'مشاركة السجل'),
                ),
              ),
              child: const Text('📤 مشاركة'),
            ),
            TextButton(
              onPressed: () async {
                await log.clear();
                setDialog(() => text = '');
              },
              child: const Text('🗑️ مسح'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ZadColors.canvasMid,
    appBar: AppBar(
      backgroundColor: ZadColors.surface,
      titleSpacing: 0,
      title: Row(
        children: <Widget>[
          const _AgentBadge(size: 40, filled: false),
          const SizedBox(width: ZadSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'مساعدة استخدام التطبيق',
                  style: ZadType.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ZadColors.ink,
                  ),
                ),
                Text(
                  'أسئلة عامة — مش وصل لحسابك الشخصي',
                  style: ZadType.labelSmall.copyWith(color: ZadColors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: <Widget>[
        IconButton(
          tooltip: 'سجل الأعطال',
          icon: Icon(Icons.bug_report, color: ZadColors.inkMuted),
          onPressed: () => unawaited(_crashLog()),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: ZadColors.outlineVariant),
      ),
    ),
    body: Column(
      children: <Widget>[
        Expanded(
          child: ListView.separated(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(
              horizontal: ZadSpacing.lg,
              vertical: ZadSpacing.lg,
            ),
            itemCount: _messages.length + (_typing ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: ZadSpacing.md),
            itemBuilder: (context, i) => i == _messages.length
                ? const _Typing()
                : _Bubble(_messages[i])
                      .animate()
                      .fadeIn(duration: ZadDuration.quick)
                      .moveY(begin: 8, curve: ZadCurves.standard),
          ),
        ),
        ColoredBox(
          color: ZadColors.surface,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(ZadSpacing.lg),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => unawaited(_send()),
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالتك هنا...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: ZadSpacing.lg,
                          vertical: ZadSpacing.md,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: ZadColors.outlineVariant,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: ZadColors.green700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: ZadSpacing.md),
                  SizedBox.square(
                    dimension: 48,
                    child: IconButton.filled(
                      tooltip: 'إرسال',
                      style: IconButton.styleFrom(
                        backgroundColor: ZadColors.green700,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _typing ? null : () => unawaited(_send()),
                      icon: const Icon(ZadIcons.send),
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

class _AgentBadge extends StatelessWidget {
  const new({required this.size, required this.filled});

  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: filled
          ? ZadColors.green700
          : ZadColors.green700.withValues(alpha: 0.1),
    ),
    child: Icon(
      Icons.support_agent,
      size: size * 0.55,
      color: filled ? Colors.white : ZadColors.green700,
    ),
  );
}

class _Bubble extends StatelessWidget {
  const new(this.message);

  final _Message message;

  @override
  Widget build(BuildContext context) {
    final user = message.isUser;
    const r = Radius.circular(16);
    const tail = Radius.circular(4);
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.75,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: user ? ZadColors.green700 : ZadColors.surface,
          borderRadius: BorderRadiusDirectional.only(
            topStart: r,
            topEnd: r,
            bottomStart: user ? r : tail,
            bottomEnd: user ? tail : r,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(ZadSpacing.md),
          child: Text(
            message.text,
            style: ZadType.bodyMedium.copyWith(
              height: 1.6,
              color: user ? Colors.white : ZadColors.ink,
            ),
          ),
        ),
      ),
    );
    return Row(
      mainAxisAlignment: user ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        if (!user) ...<Widget>[
          const _AgentBadge(size: 32, filled: true),
          const SizedBox(width: ZadSpacing.sm),
        ],
        Flexible(child: bubble),
      ],
    );
  }
}

class _Typing extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      const SizedBox(width: 40),
      DecoratedBox(
        decoration: BoxDecoration(
          color: ZadColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(ZadSpacing.md),
          child: Text(
            'جاري الكتابة...',
            style: ZadType.labelMedium.copyWith(color: ZadColors.inkMuted),
          ),
        ),
      ),
    ],
  );
}
