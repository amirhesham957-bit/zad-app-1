/// Kotlin's `TelegramBinding.kt`: the binding section, the bot sheet, the
/// first-visit link sheet, the home banner and the community card.
///
/// Binding is one tap: `https://t.me/<bot>?start=<code>` reaches the bot as
/// literally `/start <code>`, which `zad-telegram-bot` already binds on. The
/// code stays visible with a copy target and a manual line, because the deep
/// link fails on a phone with neither Telegram nor a browser.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zad/design/foundation/compose_shadow.dart';
import 'package:zad/design/tokens/zad_extended_colors.dart';
import 'package:zad/design/tokens/zad_icons.dart';
import 'package:zad/design/tokens/zad_palette.dart';
import 'package:zad/design/tokens/zad_typography.dart';
import 'package:zad/features/telegram/data/telegram_link.dart';

const Color _brand = ZadPalette.brandTelegram;

void _toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

Future<void> _openUrl(BuildContext context, Uri uri) async {
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object {
    opened = false;
  }
  if (!opened && context.mounted) {
    _toast(context, 'مفيش تطبيق تليجرام أو متصفح على الجهاز');
  }
}

/// Kotlin's `TelegramBindingSection`.
class TelegramBindingSection extends ConsumerStatefulWidget {
  /// Creates the section.
  const new({super.key});

  @override
  ConsumerState<TelegramBindingSection> createState() => _BindingState();
}

class _BindingState extends ConsumerState<TelegramBindingSection> {
  bool? _linked;
  String? _code;
  bool _busy = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    // The binding completes in Telegram, so the only moment this screen can
    // learn of it is when the customer comes back.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (_linked != true) unawaited(_load());
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final remote = ref.read(telegramLinkRemoteProvider);
    final linked = await remote.linkStatus() ?? false;
    if (!mounted) return;
    setState(() => _linked = linked);
    // Only mint a code when there is something to bind — otherwise every
    // visit would insert a throwaway row.
    if (!linked && _code == null) {
      final code = await remote.generateBindingCode();
      if (mounted) setState(() => _code = code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = context.zadExt;
    final linked = _linked;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: kZadCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const _BrandTile(size: 44, radius: 13, alpha: 0.12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'ربط تليجرام',
                      style: ZadType.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      'شوف رصيدك ومعاملاتك من بوت زاد',
                      style: ZadType.bodySmall.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (linked != null) ...<Widget>[
                const SizedBox(width: 12),
                _StatusChip(linked: linked),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ..._body(context, scheme, ext),
        ],
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    ColorScheme scheme,
    ZadExtendedColors ext,
  ) {
    final linked = _linked;
    if (linked == null) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ];
    }
    if (linked) {
      return <Widget>[
        Text(
          'حسابك مربوط بتليجرام بالفعل ✅',
          style: ZadType.bodyMedium.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: () async {
              if (_busy) return;
              setState(() => _busy = true);
              await ref.read(telegramLinkRemoteProvider).unlink();
              if (!mounted) return;
              setState(() {
                _code = null;
                _busy = false;
              });
              await _load();
            },
            child: Text('فصل الربط', style: TextStyle(color: scheme.error)),
          ),
        ),
      ];
    }
    final code = _code;
    if (code == null) {
      return <Widget>[
        Text(
          'معرفناش نولّد كود — جرب تاني',
          style: ZadType.bodyMedium.copyWith(color: scheme.error),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: () {
              if (!_busy) unawaited(_load());
            },
            child: const Text('كود جديد'),
          ),
        ),
      ];
    }
    return <Widget>[
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            'بوت زاد على تليجرام',
            style: ZadType.labelMedium.copyWith(color: scheme.onSurfaceVariant),
          ),
          Text(
            '@$kTelegramBotUsername',
            style: ZadType.labelLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: _brand,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Material(
        color: ext.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: code));
            if (context.mounted) _toast(context, 'تم نسخ الكود');
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  code,
                  style: ZadType.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                    letterSpacing: 3,
                  ),
                ),
                Icon(
                  Icons.content_copy,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 48,
        child: FilledButton(
          onPressed: () => _openUrl(
            context,
            Uri.parse('https://t.me/$kTelegramBotUsername?start=$code'),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _brand,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.send, size: 18),
              SizedBox(width: 8),
              Text(
                'افتح البوت واربط تلقائياً',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'مش اشتغل الزرار؟ ابعت للبوت: /start ‏$code',
        style: ZadType.labelSmall.copyWith(color: scheme.onSurfaceVariant),
      ),
      const SizedBox(height: 12),
      Text(
        'الكود صالح ١٠ دقايق بس — دوس عليه عشان تنسخه',
        style: ZadType.labelSmall.copyWith(color: ext.textTertiary),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: TextButton(
          onPressed: () async {
            if (_busy) return;
            setState(() => _busy = true);
            final fresh = await ref
                .read(telegramLinkRemoteProvider)
                .generateBindingCode();
            if (mounted) {
              setState(() {
                _code = fresh;
                _busy = false;
              });
            }
          },
          child: const Text('كود جديد'),
        ),
      ),
    ];
  }
}

class _StatusChip extends StatelessWidget {
  const new({required this.linked});

  final bool linked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = context.zadExt;
    final tone = linked ? ext.success : ext.textTertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            linked ? 'مربوط بتليجرام' : 'مش مربوط',
            style: ZadType.labelSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: linked ? ext.success : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandTile extends StatelessWidget {
  const new({required this.size, required this.radius, required this.alpha});

  final double size;
  final double radius;
  final double alpha;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: _brand.withValues(alpha: alpha),
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Icon(Icons.send, size: size / 2, color: _brand),
  );
}

/// Kotlin's `TelegramBotSheet`: the binding section in a bottom sheet, so
/// the network calls stay on the tap.
Future<void> showTelegramBotSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.zadExt.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: TelegramBindingSection(),
        ),
      ),
    );

/// Kotlin's `TelegramLinkPromptSheet`: what linking brings, the loss without
/// it, then the same binding section — there is no second binding path.
Future<void> showTelegramLinkPromptSheet(
  BuildContext context,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: context.zadExt.surfaceContainerLow,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (sheetContext) {
    final scheme = Theme.of(sheetContext).colorScheme;
    const voice =
        'ينبهك بفويس بصوت زاد للحاجات المهمة: دوا اتفوّت، ميعاد قرّب، '
        'ميزانية في خطر';
    const benefits = <String>[
      'يأكد معاك أي حركة بنكية قبل ما تتحسب من رصيدك',
      'ينبهك بالنواقص والفواتير اللي قربت',
      'يبعتلك ملخص البيت وتوقع الصرف',
      'تسجل مصروفك برسالة واحدة',
      voice,
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'خلّي زاد يكلمك على تيليجرام',
              style: ZadType.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'اربط حسابك مرة واحدة، وزاد يوصلك بالمهم حتى لو التطبيق مقفول.',
              style: ZadType.bodyMedium.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < benefits.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: _brand,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      benefits[i],
                      style: ZadType.bodyMedium.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '⚠️ من غير الربط مش هتوصلك التقارير ولا التنبيهات الصوتية '
                'برّه التطبيق — تجربة زاد بتبقى ناقصة.',
                style: ZadType.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.error,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const TelegramBindingSection(),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text(
                  'مش دلوقتي',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  },
);

/// Kotlin's `TelegramLinkBanner`: the loss, a link button, and a three-day
/// snooze.
class TelegramLinkBanner extends StatelessWidget {
  /// Creates the banner.
  const new({required this.onLink, required this.onSnooze, super.key});

  /// اربط دلوقتي.
  final VoidCallback onLink;

  /// مش دلوقتي.
  final VoidCallback onSnooze;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _brand.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, size: 20, color: _brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'اربط تليجرام عشان زاد توصلك',
                      style: ZadType.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'التقارير وتأكيد حركات البنك وفويسات زاد (صباح الخير، '
                      'الدوا، المواعيد) كلها بتوصل على تليجرام. من غير الربط '
                      'مش هتوصلك.',
                      style: ZadType.bodySmall.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: onLink,
                  style: FilledButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: scheme.onPrimary,
                    minimumSize: const Size(0, 44),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'اربط دلوقتي',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: onSnooze,
                child: Text(
                  'مش دلوقتي',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kotlin's `ZadTelegramCommunityCard`: opens the bot.
class ZadTelegramCommunityCard extends StatelessWidget {
  /// Creates the card.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: kZadCardShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openUrl(
            context,
            Uri.parse('https://t.me/$kTelegramBotUsername'),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                const _BrandTile(size: 44, radius: 13, alpha: 0.14),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'مجتمع زاد على تليجرام',
                        style: ZadType.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        'انضم لقناتنا لتحديثات الأسعار والذكاء الاصطناعي',
                        style: ZadType.bodySmall.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  ZadIcons.forward,
                  size: 20,
                  color: context.zadExt.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Home's Telegram blocks under the sections grid (Kotlin's order): the
/// banner while the account is not linked, then the community card. Also
/// raises the first-visit link sheet when it is due.
class HomeTelegramBlocks extends ConsumerWidget {
  /// Creates the blocks.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(telegramHomeControllerProvider.select((s) => s.promptDue), (
      _,
      due,
    ) {
      if (!due) return;
      // Counted when it actually shows, once per session.
      ref.read(telegramHomeControllerProvider.notifier).promptShown();
      unawaited(showTelegramLinkPromptSheet(context));
    });
    final state = ref.watch(telegramHomeControllerProvider);
    final controller = ref.read(telegramHomeControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: state.bannerVisible
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TelegramLinkBanner(
                    onLink: () async {
                      await showTelegramBotSheet(context);
                      await controller.recheckAfterSheet();
                    },
                    onSnooze: controller.snoozeBanner,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        const ZadTelegramCommunityCard(),
      ],
    );
  }
}
